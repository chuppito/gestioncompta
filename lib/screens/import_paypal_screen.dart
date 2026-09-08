import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../models/produit.dart';
import '../models/vente.dart';
import '../services/store.dart';
import '../services/app_config.dart';

/// Enlève les accents et met en minuscules, pour comparer des noms de
/// produits de façon tolérante ("Supplément" vs "supplement").
String _normalise(String s) {
  const avec = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ';
  const sans = 'aaaaaaceeeeiiiinooooouuuuyy';
  var out = s.toLowerCase().trim();
  for (var i = 0; i < avec.length; i++) {
    out = out.replaceAll(avec[i], sans[i]);
  }
  return out;
}

class ImportPaypalScreen extends StatefulWidget {
  const ImportPaypalScreen({super.key});

  @override
  State<ImportPaypalScreen> createState() => _ImportPaypalScreenState();
}

class _ImportPaypalScreenState extends State<ImportPaypalScreen> {
  bool _lecture = false;
  String? _erreur;

  List<PayPalRecu>? _recus;
  int _dejaImportes = 0;
  double _montantNouveaux = 0;
  Set<String> _nomsNonReconnus = {};

  Future<void> _choisirFichier() async {
    setState(() {
      _erreur = null;
      _recus = null;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.single.bytes;
    if (bytes == null) {
      setState(() => _erreur = "Impossible de lire le fichier sélectionné.");
      return;
    }

    setState(() => _lecture = true);
    try {
      final recus = _parseFichier(bytes);
      final existants = Store.I.refsExternesExistantes();

      final dejaImportes =
          recus.where((r) => existants.contains(r.refExterne)).length;
      final nouveaux = recus.where((r) => !existants.contains(r.refExterne));
      final montant = nouveaux.fold<double>(
          0, (s, r) => s + r.items.fold<double>(0, (s2, i) => s2 + i.sousTotal));

      setState(() {
        _recus = recus;
        _dejaImportes = dejaImportes;
        _montantNouveaux = montant;
        _lecture = false;
      });
    } catch (e) {
      setState(() {
        _erreur =
            "Le fichier n'a pas pu être lu (format inattendu). Détail : $e";
        _lecture = false;
      });
    }
  }

  /// Lit le rapport "Activité détaillée" PayPal et regroupe les lignes par
  /// numéro de reçu.
  List<PayPalRecu> _parseFichier(Uint8List bytes) {
    final excelFile = Excel.decodeBytes(bytes);
    final sheet = excelFile.tables[excelFile.tables.keys.first]!;
    final rows = sheet.rows;

    // Cherche la ligne d'en-tête (celle qui contient "Reçu n°").
    int headerIndex = -1;
    for (var i = 0; i < rows.length; i++) {
      final texte = rows[i].map((c) => _texte(c?.value)).join('|');
      if (texte.contains("Reçu n°")) {
        headerIndex = i;
        break;
      }
    }
    if (headerIndex == -1) {
      throw Exception(
          "en-tête introuvable (colonne 'Reçu n°' non trouvée) — ce n'est peut-être pas un export PayPal POS.");
    }

    final produits = Store.I.produits;
    Produit? trouverProduit(String nom) {
      final n = _normalise(nom);
      for (final p in produits) {
        if (_normalise(p.nom) == n) return p;
      }
      return null;
    }

    final groupes = <String, List<VenteItem>>{};
    final dates = <String, DateTime>{};

    for (var i = headerIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 11) continue;

      final date = _date(row[0]?.value);
      final recuRaw = _texte(row[3]?.value);
      final nom = _texte(row[4]?.value);
      final variante = _texte(row[5]?.value);
      final quantite = _nombre(row[7]?.value)?.toInt() ?? 1;
      final prixFinal = _nombre(row[10]?.value) ?? 0;

      if (recuRaw.isEmpty || nom.isEmpty || date == null) continue;

      // "4581.0" -> "4581"
      final recu = recuRaw.replaceAll(RegExp(r'\.0$'), '');
      final ref = "paypal_$recu";

      final nomComplet = variante.isEmpty ? nom : "$nom ($variante)";
      final produit = trouverProduit(nom);
      if (produit == null) _nomsNonReconnus.add(nom);

      final item = VenteItem(
        produitId: produit?.id ?? "",
        nom: nomComplet,
        prixUnitaire: quantite == 0 ? 0 : prixFinal / quantite,
        quantite: quantite,
        categorie: produit?.categorie ?? "",
      );

      groupes.putIfAbsent(ref, () => []).add(item);
      dates.putIfAbsent(ref, () => date);
    }

    return groupes.entries
        .map((e) => PayPalRecu(
              refExterne: e.key,
              date: dates[e.key]!,
              items: e.value,
            ))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  String _texte(CellValue? v) {
    if (v == null) return '';
    if (v is TextCellValue) return v.value.toString().trim();
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) return v.value.toString();
    return v.toString().trim();
  }

  double? _nombre(CellValue? v) {
    if (v == null) return null;
    if (v is DoubleCellValue) return v.value;
    if (v is IntCellValue) return v.value.toDouble();
    if (v is TextCellValue) {
      return double.tryParse(v.value.toString().replaceAll(',', '.'));
    }
    return double.tryParse(v.toString());
  }

  DateTime? _date(CellValue? v) {
    if (v == null) return null;
    if (v is DateTimeCellValue) {
      return DateTime(v.year, v.month, v.day);
    }
    if (v is DateCellValue) {
      return DateTime(v.year, v.month, v.day);
    }
    if (v is TextCellValue) {
      final d = DateTime.tryParse(v.value.toString());
      return d == null ? null : DateTime(d.year, d.month, d.day);
    }
    return null;
  }

  void _confirmerImport() {
    if (_recus == null) return;
    final resultat = Store.I.importerPayPal(_recus!);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "${resultat.nouveaux} vente(s) importée(s)"
          "${resultat.dejaImportes > 0 ? ' • ${resultat.dejaImportes} déjà présente(s), ignorée(s)' : ''}",
        ),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = AppConfig.I;
    final nouveaux = (_recus?.length ?? 0) - _dejaImportes;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Importer un rapport PayPal"),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Sélectionne le fichier .xlsx exporté depuis PayPal "
              "(Rapports > Activité détaillée). L'appli reconnaît "
              "automatiquement les ventes déjà importées, tu peux "
              "réimporter le même fichier sans créer de doublon.",
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _lecture ? null : _choisirFichier,
              icon: const Icon(Icons.file_open),
              label: Text(_recus == null
                  ? "Choisir le fichier PayPal (.xlsx)"
                  : "Choisir un autre fichier"),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              ),
            ),
            const SizedBox(height: 20),
            if (_lecture) const Center(child: CircularProgressIndicator(color: kPrimary)),
            if (_erreur != null)
              Text(_erreur!, style: const TextStyle(color: Colors.red)),
            if (_recus != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${_recus!.length} vente(s) trouvée(s) dans le fichier",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      if (_dejaImportes > 0)
                        Text(
                          "$_dejaImportes déjà importée(s) — seront ignorées",
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      Text(
                        "$nouveaux nouvelle(s) vente(s) à importer",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      Text(
                        "Montant : ${_montantNouveaux.toStringAsFixed(2)} ${cfg.currency}",
                      ),
                      if (_nomsNonReconnus.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          "Non reconnus (pas de produit correspondant dans "
                          "\"Mes produits\" — importés quand même, mais sans "
                          "catégorie pour les statistiques) :",
                          style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                        ),
                        Text(
                          _nomsNonReconnus.join(', '),
                          style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: nouveaux == 0 ? null : _confirmerImport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(nouveaux == 0
                      ? "Rien de nouveau à importer"
                      : "Importer $nouveaux vente(s)"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
