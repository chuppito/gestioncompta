import 'package:flutter/material.dart';
import '../theme.dart';

import '../services/store.dart';
import '../services/app_config.dart';
import '../models/vente.dart';
import 'nouvelle_vente_screen.dart';


class VenteDetailScreen extends StatelessWidget {
  final Vente vente;
  const VenteDetailScreen({super.key, required this.vente});

  @override
  Widget build(BuildContext context) {
    final cfg = AppConfig.I;

    return Scaffold(
      appBar: AppBar(
        title: Text(vente.label),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: "Modifier la vente",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NouvelleVenteScreen(
                    dateInitiale: vente.date,
                    venteAModifier: vente,
                  ),
                ),
              ).then((_) {
                if (context.mounted) Navigator.pop(context);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmerSuppression(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${vente.date.day.toString().padLeft(2, '0')}/"
                  "${vente.date.month.toString().padLeft(2, '0')}/"
                  "${vente.date.year}",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text("Mode de paiement : ${vente.mode.label}"),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: vente.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = vente.items[index];
                return ListTile(
                  title: Row(
                    children: [
                      Text(item.nom),
                      if (item.offert) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.quantiteOfferte == item.quantite
                                ? (item.quantite > 1
                                    ? "TOUTES OFFERTES"
                                    : "OFFERTE")
                                : "${item.quantiteOfferte} OFFERTE${item.quantiteOfferte > 1 ? 'S' : ''}",
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                      "${item.quantite} x ${item.prixUnitaire.toStringAsFixed(2)} ${cfg.currency}"),
                  trailing: Text(
                    "${item.sousTotal.toStringAsFixed(2)} ${cfg.currency}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (vente.remise > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Sous-total", style: TextStyle(color: Colors.grey)),
                        Text(
                          "${(vente.total + vente.remise).toStringAsFixed(2)} ${cfg.currency}",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Remise", style: TextStyle(color: Colors.redAccent)),
                        Text(
                          "- ${vente.remise.toStringAsFixed(2)} ${cfg.currency}",
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                    ),
                    const Divider(),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Total", style: TextStyle(fontSize: 18)),
                      Text(
                        "${vente.total.toStringAsFixed(2)} ${cfg.currency}",
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmerSuppression(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer cette vente ?"),
        content: Text(
            "${vente.label} et la recette associée dans le calendrier seront supprimées."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              Store.I.deleteVente(vente);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
  }
}
