import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../services/store.dart';
import '../services/app_config.dart';
import '../services/auth_service.dart';
import '../models/operation.dart';
import '../models/produit.dart';
import '../models/vente.dart';
import 'produits_screen.dart';
import 'login_screen.dart';


class Parametres extends StatefulWidget {
  const Parametres({super.key});

  @override
  State<Parametres> createState() => _ParametresState();
}

class _ParametresState extends State<Parametres> {
  @override
  Widget build(BuildContext context) {
    final s = Store.I;
    final cfg = AppConfig.I;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Réglages"),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          _sectionCompte(context),
          const Divider(),
          ListTile(
            title: const Text("Resynchroniser toutes les ventes"),
            subtitle: const Text(
                "Récupère les ventes/opérations qui manqueraient en local (rare, peut prendre quelques secondes)"),
            leading: const Icon(Icons.sync, color: kPrimary),
            onTap: () => _resynchroniserTout(context, s),
          ),
          const Divider(),
          ListTile(
            title: const Text("Pointer le passé"),
            subtitle: const Text("Marque toutes les opérations passées comme pointées"),
            leading: const Icon(Icons.check_circle_outline, color: Colors.green),
            onTap: () => _pointPast(s),
          ),
          ListTile(
            title: const Text("Ajuster le solde"),
            subtitle: const Text("Corriger le solde réel du compte actif"),
            leading: const Icon(Icons.account_balance_wallet, color: Colors.orange),
            onTap: () => _adjustBalance(context, s, cfg),
          ),
          const Divider(),
          ListTile(
            title: const Text("Mes produits / articles"),
            subtitle: const Text("Gérer le catalogue utilisé pour les ventes"),
            leading: const Icon(Icons.inventory_2_outlined, color: Colors.teal),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProduitsScreen()),
              ).then((_) => setState(() {}));
            },
          ),
          const Divider(),
          ListTile(
            title: const Text("Devise"),
            subtitle: Text(cfg.currency),
            leading: const Icon(Icons.edit_note, color: Colors.blueGrey),
            onTap: () => _showCurrencyEditor(context, cfg),
          ),
          const Divider(),
          ListTile(
            title: const Text("Exporter mes comptes"),
            subtitle: const Text("Sauvegarde complète (JSON)"),
            leading: const Icon(Icons.upload_file, color: Colors.indigo),
            onTap: () => _exportData(s),
          ),
          ListTile(
            title: const Text("Importer une sauvegarde"),
            leading: const Icon(Icons.download, color: Colors.indigo),
            onTap: () => _importData(s),
          ),
          const Divider(),
          ListTile(
            title: const Text("Nouveau compte"),
            leading: const Icon(Icons.add_business, color: Colors.green),
            onTap: () => _addBank(context, s),
          ),
          ListTile(
            title: const Text("Supprimer le compte actif"),
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: () => _confirmDeleteBank(context, s),
          ),
        ],
      ),
    );
  }

  // ===================== COMPTE (connexion / synchronisation) =====================
  Widget _sectionCompte(BuildContext context) {
    String? email;
    try {
      email = AuthService.currentUser?.email;
    } catch (_) {
      // Firebase pas encore configuré (voir firebase_options.dart)
      email = null;
    }

    if (email != null) {
      final uid = AuthService.currentUser?.uid ?? "";
      return Column(
        children: [
          ListTile(
            title: Text(email),
            subtitle: const Text("Connecté — tes données sont synchronisées"),
            leading: const Icon(Icons.cloud_done, color: Colors.green),
            trailing: TextButton(
              onPressed: () => _seDeconnecter(context),
              child: const Text("Déconnexion"),
            ),
          ),
          ListTile(
            dense: true,
            title: const Text("Identifiant compte (uid)", style: TextStyle(fontSize: 12)),
            subtitle: Text(uid, style: const TextStyle(fontSize: 11)),
            leading: const Icon(Icons.fingerprint, color: Colors.grey, size: 20),
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: "Copier (utile pour la synchro PayPal)",
              onPressed: () {
                Clipboard.setData(ClipboardData(text: uid));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("uid copié")),
                );
              },
            ),
          ),
        ],
      );
    }

    return ListTile(
      title: const Text("Non connecté"),
      subtitle: const Text("Connecte-toi pour synchroniser tes données entre tes téléphones"),
      leading: const Icon(Icons.cloud_off, color: Colors.grey),
      trailing: TextButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ).then((_) => setState(() {}));
        },
        child: const Text("Se connecter"),
      ),
    );
  }

  void _seDeconnecter(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Se déconnecter ?"),
        content: const Text(
          "Tes données restent sur ce téléphone. Reconnecte-toi avec le même "
          "compte pour les retrouver ailleurs.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () async {
              Store.I.stopRealtimeSync();
              await AuthService.signOut();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text("Se déconnecter"),
          ),
        ],
      ),
    );
  }

  // ===================== POINTAGE =====================
  void _pointPast(Store s) {
    setState(() {
      s.autoPointAllPast();
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Solde mis à jour")));
  }

  // ===================== RESYNCHRONISATION MANUELLE =====================
  Future<void> _resynchroniserTout(BuildContext context, Store s) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: kPrimary)),
    );

    final resultat = await s.resynchroniserTout();

    if (!context.mounted) return;
    Navigator.pop(context); // ferme le rond de chargement

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultat.ventesMaj == 0 && resultat.opsMaj == 0
              ? "Déjà à jour, rien à récupérer"
              : "${resultat.ventesMaj} vente(s) et ${resultat.opsMaj} opération(s) mises à jour",
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ===================== AJUSTEMENT =====================
  void _adjustBalance(BuildContext context, Store s, AppConfig cfg) {
    if (s.active == null) return;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ajuster le solde"),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: "Nouveau solde",
            suffixText: cfg.currency,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.replaceAll(',', '.'));
              if (val == null || s.active == null) return;

              final current = s.getSoldeAu(DateTime.now(), false);
              final diff = val - current;

              if (diff != 0) {
                final now = DateTime.now();
                final op = Operation(
                  id: now.millisecondsSinceEpoch.toString(),
                  desc: "Ajustement de solde",
                  montant: diff.abs(),
                  depense: diff < 0,
                  date: now,
                  banque: s.active!,
                );
                op.togglePointage(DateTime(now.year, now.month, now.day));

                setState(() {
                  s.ops.add(op);
                  s.save();
                });
              }

              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  // ===================== IMPORT =====================
  Future<void> _importData(Store s) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final data = jsonDecode(content);

      setState(() {
        s.banques = List<String>.from(data['banques'] ?? []);
        s.ops = (data['ops'] as List? ?? [])
            .map((o) => Operation.fromMap(Map<String, dynamic>.from(o)))
            .toList();
        s.produits = (data['produits'] as List? ?? [])
            .map((p) => Produit.fromMap(Map<String, dynamic>.from(p)))
            .toList();
        s.ventes = (data['ventes'] as List? ?? [])
            .map((v) => Vente.fromMap(Map<String, dynamic>.from(v)))
            .toList();

        if (s.banques.isNotEmpty) {
          s.active = s.banques.first;
        }

        s.save();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Import terminé")));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fichier invalide")),
      );
    }
  }

  // ===================== EXPORT =====================
  Future<void> _exportData(Store s) async {
    try {
      final data = {
        'banques': s.banques,
        'ops': s.ops.map((o) => o.toMap()).toList(),
        'produits': s.produits.map((p) => p.toMap()).toList(),
        'ventes': s.ventes.map((v) => v.toMap()).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      final dir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final file = File('${dir.path}/gestioncompta_export_$dateStr.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Export Gestion Compta',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de l'export")),
      );
    }
  }

  // ===================== DEVISE =====================
  void _showCurrencyEditor(BuildContext context, AppConfig cfg) {
    final controller = TextEditingController(text: cfg.currency);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Devise"),
        content: TextField(
          controller: controller,
          maxLength: 3,
          decoration: const InputDecoration(hintText: "Symbole actuel"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              cfg.updateCurrency(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  // ===================== COMPTE =====================
  void _addBank(BuildContext context, Store s) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nouveau compte"),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              setState(() {
                s.banques.add(name);
                s.active = name;
                s.save();
              });

              Navigator.pop(ctx);
            },
            child: const Text("Créer"),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteBank(BuildContext context, Store s) {
    if (s.active == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer le compte"),
        content: Text("Supprimer définitivement '${s.active}' et toutes ses opérations ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Non"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                final banque = s.active;
                s.banques.remove(banque);
                s.ops.removeWhere((o) => o.banque == banque);
                s.ventes.removeWhere((v) => v.banque == banque);
                s.active = s.banques.isNotEmpty ? s.banques.first : null;
                s.save();
              });
              Navigator.pop(ctx);
            },
            child: const Text("Oui, supprimer"),
          ),
        ],
      ),
    );
  }
}
