import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';

import '../services/store.dart';
import '../services/app_config.dart';
import '../models/vente.dart';

enum _PeriodePaiements { jour, semaine, mois, annee }

class PaiementsRecapScreen extends StatefulWidget {
  const PaiementsRecapScreen({super.key});

  @override
  State<PaiementsRecapScreen> createState() => _PaiementsRecapScreenState();
}

class _PaiementsRecapScreenState extends State<PaiementsRecapScreen> {
  _PeriodePaiements _periode = _PeriodePaiements.mois;
  DateTime _dateRef = DateTime.now();

  /// [début inclus, fin exclue[ de la période sélectionnée.
  (DateTime, DateTime) _bornesPeriode() {
    final d = DateTime(_dateRef.year, _dateRef.month, _dateRef.day);
    switch (_periode) {
      case _PeriodePaiements.jour:
        return (d, d.add(const Duration(days: 1)));
      case _PeriodePaiements.semaine:
        final debut = d.subtract(Duration(days: d.weekday - 1)); // lundi
        return (debut, debut.add(const Duration(days: 7)));
      case _PeriodePaiements.mois:
        final debut = DateTime(d.year, d.month, 1);
        final fin = DateTime(d.year, d.month + 1, 1);
        return (debut, fin);
      case _PeriodePaiements.annee:
        return (DateTime(d.year, 1, 1), DateTime(d.year + 1, 1, 1));
    }
  }

  void _naviguer(int direction) {
    setState(() {
      switch (_periode) {
        case _PeriodePaiements.jour:
          _dateRef = _dateRef.add(Duration(days: direction));
          break;
        case _PeriodePaiements.semaine:
          _dateRef = _dateRef.add(Duration(days: 7 * direction));
          break;
        case _PeriodePaiements.mois:
          _dateRef = DateTime(_dateRef.year, _dateRef.month + direction, 1);
          break;
        case _PeriodePaiements.annee:
          _dateRef = DateTime(_dateRef.year + direction, _dateRef.month, 1);
          break;
      }
    });
  }

  String _libellePeriode() {
    final (debut, fin) = _bornesPeriode();
    switch (_periode) {
      case _PeriodePaiements.jour:
        return DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(debut);
      case _PeriodePaiements.semaine:
        final finIncluse = fin.subtract(const Duration(days: 1));
        return "Semaine du ${DateFormat('d MMM', 'fr_FR').format(debut)} au ${DateFormat('d MMM yyyy', 'fr_FR').format(finIncluse)}";
      case _PeriodePaiements.mois:
        return DateFormat.yMMMM('fr_FR').format(debut);
      case _PeriodePaiements.annee:
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

    // Total net encaissé par mode de paiement (remise déjà déduite dans
    // v.total).
    final Map<ModePaiement, double> totauxParMode = {
      for (final m in ModePaiement.values) m: 0,
    };
    final Map<ModePaiement, int> nbParMode = {
      for (final m in ModePaiement.values) m: 0,
    };

    for (final v in ventesPeriode) {
      totauxParMode[v.mode] = (totauxParMode[v.mode] ?? 0) + v.total;
      nbParMode[v.mode] = (nbParMode[v.mode] ?? 0) + 1;
    }

    final totalGeneral = totauxParMode.values.fold<double>(0, (s, v) => s + v);

    // On n'affiche que les modes réellement utilisés sur la période, du
    // plus gros montant au plus petit.
    final modesUtilises = ModePaiement.values.where((m) => nbParMode[m]! > 0).toList()
      ..sort((a, b) => totauxParMode[b]!.compareTo(totauxParMode[a]!));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Récapitulatif des paiements"),
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
                  children: _PeriodePaiements.values.map((p) {
                    final selected = _periode == p;
                    const labels = {
                      _PeriodePaiements.jour: "Jour",
                      _PeriodePaiements.semaine: "Semaine",
                      _PeriodePaiements.mois: "Mois",
                      _PeriodePaiements.annee: "Année",
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
                        textAlign: TextAlign.center,
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.grey.shade100,
              child: Column(
                children: [
                  const Text("Total encaissé", style: TextStyle(color: Colors.grey)),
                  Text(
                    "${totalGeneral.toStringAsFixed(2)} ${cfg.currency}",
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: modesUtilises.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final mode = modesUtilises[index];
                  final total = totauxParMode[mode]!;
                  final nb = nbParMode[mode]!;
                  final part = totalGeneral == 0 ? 0.0 : total / totalGeneral;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _couleurMode(mode),
                      child: Icon(_iconeMode(mode), color: Colors.white, size: 20),
                    ),
                    title: Text(mode.label),
                    subtitle: Text(
                      "$nb vente${nb > 1 ? 's' : ''} · ${(part * 100).toStringAsFixed(0)}% du total",
                    ),
                    trailing: Text(
                      "${total.toStringAsFixed(2)} ${cfg.currency}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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

  Color _couleurMode(ModePaiement m) {
    switch (m) {
      case ModePaiement.especes:
        return Colors.green.shade600;
      case ModePaiement.cb:
        return Colors.blue.shade600;
      case ModePaiement.cheque:
        return Colors.brown.shade400;
      case ModePaiement.wero:
        return Colors.purple.shade400;
      case ModePaiement.paypal:
        return const Color(0xFF003087);
      case ModePaiement.autre:
        return Colors.grey;
      case ModePaiement.ticketRestaurant:
        return Colors.deepOrange;
    }
  }

  IconData _iconeMode(ModePaiement m) {
    switch (m) {
      case ModePaiement.especes:
        return Icons.payments;
      case ModePaiement.cb:
        return Icons.credit_card;
      case ModePaiement.cheque:
        return Icons.receipt_long;
      case ModePaiement.wero:
        return Icons.bolt;
      case ModePaiement.paypal:
        return Icons.account_balance_wallet;
      case ModePaiement.autre:
        return Icons.more_horiz;
      case ModePaiement.ticketRestaurant:
        return Icons.restaurant;
    }
  }
}
