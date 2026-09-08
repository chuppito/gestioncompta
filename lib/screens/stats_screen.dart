import 'package:flutter/material.dart';
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

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String? _categorieFiltre;

  @override
  Widget build(BuildContext context) {
    final s = Store.I;
    final cfg = AppConfig.I;
    final ventes = s.ventesActives();

    // Regroupe toutes les lignes vendues par nom de produit.
    final Map<String, _StatLigne> parNom = {};
    for (final v in ventes) {
      for (final item in v.items) {
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
      body: ventes.isEmpty
          ? const Center(child: Text("Aucune vente enregistrée pour l'instant"))
          : Column(
              children: [
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
                          selectedColor: kPrimary.withOpacity(0.15),
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
            ),
    );
  }
}
