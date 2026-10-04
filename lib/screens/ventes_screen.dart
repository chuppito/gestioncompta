import 'package:flutter/material.dart';
import '../theme.dart';

import '../services/store.dart';
import '../services/app_config.dart';
import '../models/vente.dart';
import 'vente_detail_screen.dart';
import 'nouvelle_vente_screen.dart';
import 'import_paypal_screen.dart';
import 'stats_screen.dart';


class VentesScreen extends StatefulWidget {
  const VentesScreen({super.key});

  @override
  State<VentesScreen> createState() => _VentesScreenState();
}

class _VentesScreenState extends State<VentesScreen> {
  static const _mois = [
    "Janvier", "Février", "Mars", "Avril", "Mai", "Juin",
    "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre",
  ];

  /// Mois actuellement affiché (premier jour du mois).
  DateTime _moisAffiche = DateTime(DateTime.now().year, DateTime.now().month);

  void _moisPrecedent() {
    setState(() {
      _moisAffiche = DateTime(_moisAffiche.year, _moisAffiche.month - 1);
    });
  }

  void _moisSuivant() {
    setState(() {
      _moisAffiche = DateTime(_moisAffiche.year, _moisAffiche.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Store.I,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final s = Store.I;
    final cfg = AppConfig.I;
    final toutesLesVentes = s.ventesActives();

    final ventes = toutesLesVentes
        .where((v) =>
            v.date.year == _moisAffiche.year &&
            v.date.month == _moisAffiche.month)
        .toList();

    final totalMois = ventes.fold<double>(0, (sum, v) => sum + v.total);

    final moisEnCours = _moisAffiche.year == DateTime.now().year &&
        _moisAffiche.month == DateTime.now().month;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ventes"),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.local_pizza),
            tooltip: "Statistiques produits",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: "Importer un rapport PayPal",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImportPaypalScreen()),
              ).then((_) => setState(() {}));
            },
          ),
        ],
      ),
      body: s.active == null
          ? const Center(child: Text("Créez d'abord un compte"))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  color: kPrimary.withValues(alpha: 0.08),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        color: kPrimary,
                        onPressed: _moisPrecedent,
                      ),
                      GestureDetector(
                        onTap: moisEnCours
                            ? null
                            : () => setState(() {
                                  _moisAffiche = DateTime(
                                    DateTime.now().year,
                                    DateTime.now().month,
                                  );
                                }),
                        child: Text(
                          "${_mois[_moisAffiche.month - 1]} ${_moisAffiche.year}",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        color: kPrimary,
                        onPressed: _moisSuivant,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey.shade100,
                  child: Column(
                    children: [
                      Text("${ventes.length} vente${ventes.length > 1 ? 's' : ''}"),
                      Text(
                        "${totalMois.toStringAsFixed(2)} ${cfg.currency}",
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ventes.isEmpty
                      ? const Center(child: Text("Aucune vente ce mois-ci"))
                      : ListView.builder(
                          itemCount: ventes.length,
                          itemBuilder: (context, index) {
                            final v = ventes[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _couleurMode(v.mode),
                                child: Text(
                                  v.mode.prefixe.substring(0, 1),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                              title: Text(v.label),
                              subtitle: Text(
                                "${v.date.day.toString().padLeft(2, '0')}/"
                                "${v.date.month.toString().padLeft(2, '0')}/"
                                "${v.date.year} • ${v.mode.label} • ${v.items.length} article(s)"
                                "${v.source == 'paypal' ? ' • Import PayPal' : ''}",
                              ),
                              trailing: Text(
                                "${v.total.toStringAsFixed(2)} ${cfg.currency}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VenteDetailScreen(vente: v),
                                  ),
                                ).then((_) => setState(() {}));
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: s.active == null
          ? null
          : FloatingActionButton(
              heroTag: "fab_ventes",
              backgroundColor: kPrimary,
              child: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NouvelleVenteScreen(dateInitiale: DateTime.now()),
                  ),
                ).then((_) => setState(() {}));
              },
            ),
    );
  }

  Color _couleurMode(ModePaiement m) {
    switch (m) {
      case ModePaiement.especes:
        return Colors.green;
      case ModePaiement.cb:
        return Colors.blue;
      case ModePaiement.cheque:
        return Colors.orange;
      case ModePaiement.wero:
        return Colors.purple;
      case ModePaiement.paypal:
        return const Color(0xFF003087); // bleu PayPal
      case ModePaiement.autre:
        return Colors.grey;
      case ModePaiement.ticketRestaurant:
        return Colors.deepOrange;
      case ModePaiement.mixte:
        return Colors.teal;
    }
  }
}
