import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:uuid/uuid.dart';

import '../services/store.dart';
import '../services/app_config.dart';
import '../models/produit.dart';


class ProduitsScreen extends StatefulWidget {
  const ProduitsScreen({super.key});

  @override
  State<ProduitsScreen> createState() => _ProduitsScreenState();
}

class _ProduitsScreenState extends State<ProduitsScreen> {
  @override
  Widget build(BuildContext context) {
    final s = Store.I;
    final cfg = AppConfig.I;

    // Regrouper par catégorie
    final categories = <String, List<Produit>>{};
    for (final p in s.produits) {
      categories.putIfAbsent(p.categorie, () => []).add(p);
    }
    final sortedCats = categories.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes produits / articles"),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
      ),
      body: s.produits.isEmpty
          ? const Center(
              child: Text(
                "Aucun produit.\nAjoutez vos articles pour pouvoir les\nretrouver lors de la saisie d'une vente.",
                textAlign: TextAlign.center,
              ),
            )
          : ListView(
              children: [
                for (final cat in sortedCats) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      cat,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: kPrimary,
                      ),
                    ),
                  ),
                  for (final p in categories[cat]!)
                    ListTile(
                      title: Text(p.nom),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${p.prix.toStringAsFixed(2)} ${cfg.currency}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _supprimer(context, s, p),
                          ),
                        ],
                      ),
                      onTap: () => _ouvrirEditeur(context, s, produit: p),
                    ),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimary,
        onPressed: () => _ouvrirEditeur(context, s),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _supprimer(BuildContext context, Store s, Produit p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer ce produit ?"),
        content: Text(p.nom),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              setState(() => s.removeProduit(p.id));
              Navigator.pop(ctx);
            },
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
  }

  void _ouvrirEditeur(BuildContext context, Store s, {Produit? produit}) {
    final nomCtrl = TextEditingController(text: produit?.nom ?? "");
    final prixCtrl =
        TextEditingController(text: produit?.prix.toStringAsFixed(2) ?? "");
    final catCtrl = TextEditingController(text: produit?.categorie ?? "Général");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(produit == null ? "Nouveau produit" : "Modifier le produit"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomCtrl,
              decoration: const InputDecoration(labelText: "Nom"),
            ),
            TextField(
              controller: prixCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: "Prix"),
            ),
            TextField(
              controller: catCtrl,
              decoration: const InputDecoration(labelText: "Catégorie"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              final nom = nomCtrl.text.trim();
              final prix = double.tryParse(prixCtrl.text.replaceAll(',', '.'));
              final cat = catCtrl.text.trim().isEmpty
                  ? "Général"
                  : catCtrl.text.trim();

              if (nom.isEmpty || prix == null || prix < 0) return;

              setState(() {
                if (produit == null) {
                  s.addProduit(
                    Produit(id: const Uuid().v4(), nom: nom, prix: prix, categorie: cat),
                  );
                } else {
                  produit.nom = nom;
                  produit.prix = prix;
                  produit.categorie = cat;
                  s.updateProduit(produit);
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }
}
