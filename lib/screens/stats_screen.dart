import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';

import '../services/store.dart';
import '../services/app_config.dart';

class _StatLigne {
  String nom;
  String categorie;
  int quantite = 0;
  double chiffreAffaires = 0;

  _StatLigne(this.nom, this.categorie);
}

enum _Periode { jour, semaine, mois, annee }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String? _categorieFiltre;
  _Periode _periode = _Periode.mois;
  DateTime _dateRef = DateTime.now();

  /// [début inclus, fin exclue[ de la période sélectionnée.
  (DateTime, DateTime) _bornesPeriode() {
    final d = DateTime(_dateRef.year, _dateRef.month, _dateRef.day);
    switch (_periode) {
      case _Periode.jour:
        return (d, d.add(const Duration(days: 1)));
      case _Periode.semaine:
        final debut = d.subtract(Duration(days: d.weekday - 1)); // lundi
        return (debut, debut.add(const Duration(days: 7)));
      case _Periode.mois:
        final debut = DateTime(d.year, d.month, 1);
        final fin = DateTime(d.year, d.month + 1, 1);
        return (debut, fin);
      case _Periode.annee:
        return (DateTime(d.year, 1, 1), DateTime(d.year + 1, 1, 1));
    }
  }

  void _naviguer(int direction) {
    setState(() {
      switch (_periode) {
        case _Periode.jour:
          _dateRef = _dateRef.add(Duration(days: direction));
          break;
        case _Periode.semaine:
          _dateRef = _dateRef.add(Duration(days: 7 * direction));
          break;
        case _Periode.mois:
          _dateRef = DateTime(_dateRef.year, _dateRef.month + direction, 1);
          break;
        case _Periode.annee:
          _dateRef = DateTime(_dateRef.year + direction, _dateRef.month, 1);
          break;
      }
    });
  }

  String _libellePeriode() {
    final (debut, fin) = _bornesPeriode();
    switch (_periode) {
      case _Periode.jour:
        return DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(debut);
      case _Periode.semaine:
        final finIncluse = fin.subtract(const Duration(days: 1));
        return "Semaine du ${DateFormat('d MMM', 'fr_FR').format(debut)} au ${DateFormat('d MMM yyyy', 'fr_FR').format(finIncluse)}";
      case _Periode.mois:
        return DateFormat('MMMM yyyy', 'fr_FR').format(debut);
      case _Periode.annee:
        return "${debut.year}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Store.I;
    final cfg = AppConfig.I;
    final (debut, fin) = _bornesPeriode();

    final ventesPeriode = s
        .ventesActives()
        .where((v) => !v.date.isBefore(debut) && v.date.isBefore(fin))
        .toList();

    // Regroupe toutes les lignes vendues par nom de produit. Les
    // suppléments (chorizo, mozzarella...) ne sont pas des pizzas à part
    // entière : on les exclut du classement — via la catégorie si elle est
    // renseignée, sinon via le nom (utile pour les imports PayPal où la
    // catégorie n'est pas toujours reconnue).
    final Map<String, _StatLigne> parNom = {};
    for (final v in ventesPeriode) {
      for (final item in v.items) {
        final categorieSuppl = item.categorie.toLowerCase().contains("suppl");
        final nomSuppl = item.nom.toLowerCase().contains("suppl");
        if (categorieSuppl || nomSuppl) continue;
        final key = item.nom;
        final ligne = parNom.putIfAbsent(
            key, () => _StatLigne(item.nom, item.categorie.isEmpty ? "Non classé" : item.categorie));
        ligne.quantite += item.quantite;
        ligne.chiffreAffaires += item.sousTotal;
      }
    }

    final categories = <String>{"Toutes"};
    for (final l in parNom.values) {
      categories.add(l.categorie);
    }

    var lignes = parNom.values.toList();
    if (_categorieFiltre != null && _categorieFiltre != "Toutes") {
      lignes = lignes.where((l) => l.categorie == _categorieFiltre).toList();
    }
    lignes.sort((a, b) => b.quantite.compareTo(a.quantite));

    final totalQuantite = lignes.fold<int>(0, (s, l) => s + l.quantite);
    final totalCA = lignes.fold<double>(0, (s, l) => s + l.chiffreAffaires);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Statistiques produits"),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: kPrimary.withValues(alpha: 0.06),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              children: [
                Wrap(
                  spacing: 6,
                  alignment: WrapAlignment.center,
                  children: _Periode.values.map((p) {
                    final selected = _periode == p;
                    const labels = {
                      _Periode.jour: "Jour",
                      _Periode.semaine: "Semaine",
                      _Periode.mois: "Mois",
                      _Periode.annee: "Année",
                    };
                    return ChoiceChip(
                      label: Text(labels[p]!),
                      selected: selected,
                      selectedColor: kPrimary.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: selected ? kPrimary : null,
                        fontWeight: selected ? FontWeight.bold : null,
                      ),
                      onSelected: (_) => setState(() => _periode = p),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _naviguer(-1),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _dateRef = DateTime.now()),
                      child: Text(
                        _libellePeriode(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _naviguer(1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (ventesPeriode.isEmpty)
            const Expanded(
              child: Center(child: Text("Aucune vente sur cette période")),
            )
          else ...[
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                children: categories.map((c) {
                  final selected = (_categorieFiltre ?? "Toutes") == c;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: selected,
                      selectedColor: kPrimary.withValues(alpha: 0.15),
                      onSelected: (_) => setState(() => _categorieFiltre = c),
                    ),
                  );
                }).toList(),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.grey.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text("$totalQuantite",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Text("unités vendues"),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        "${totalCA.toStringAsFixed(2)} ${cfg.currency}",
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const Text("chiffre d'affaires"),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: lignes.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final l = lignes[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: kPrimary,
                      child: Text("${index + 1}",
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    title: Text(l.nom),
                    subtitle: Text(l.categorie),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("x${l.quantite}",
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          "${l.chiffreAffaires.toStringAsFixed(2)} ${cfg.currency}",
                          style: const TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
