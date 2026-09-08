import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:intl/intl.dart';
import '../services/store.dart';
import '../services/app_config.dart';

enum _PeriodeRecap { jour, semaine, mois, annee }

class Recap extends StatefulWidget {
  const Recap({super.key});

  @override
  State<Recap> createState() => _RecapState();
}

class _RecapState extends State<Recap> {
  _PeriodeRecap _periode = _PeriodeRecap.mois;
  DateTime _dateRef = DateTime.now();

  /// [début inclus, fin exclue[ de la période sélectionnée.
  (DateTime, DateTime) _bornesPeriode() {
    final d = DateTime(_dateRef.year, _dateRef.month, _dateRef.day);
    switch (_periode) {
      case _PeriodeRecap.jour:
        return (d, d.add(const Duration(days: 1)));
      case _PeriodeRecap.semaine:
        final debut = d.subtract(Duration(days: d.weekday - 1)); // lundi
        return (debut, debut.add(const Duration(days: 7)));
      case _PeriodeRecap.mois:
        final debut = DateTime(d.year, d.month, 1);
        final fin = DateTime(d.year, d.month + 1, 1);
        return (debut, fin);
      case _PeriodeRecap.annee:
        return (DateTime(d.year, 1, 1), DateTime(d.year + 1, 1, 1));
    }
  }

  void _naviguer(int direction) {
    setState(() {
      switch (_periode) {
        case _PeriodeRecap.jour:
          _dateRef = _dateRef.add(Duration(days: direction));
          break;
        case _PeriodeRecap.semaine:
          _dateRef = _dateRef.add(Duration(days: 7 * direction));
          break;
        case _PeriodeRecap.mois:
          _dateRef = DateTime(_dateRef.year, _dateRef.month + direction, 1);
          break;
        case _PeriodeRecap.annee:
          _dateRef = DateTime(_dateRef.year + direction, _dateRef.month, 1);
          break;
      }
    });
  }

  String _libellePeriode() {
    final (debut, fin) = _bornesPeriode();
    switch (_periode) {
      case _PeriodeRecap.jour:
        return DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(debut);
      case _PeriodeRecap.semaine:
        final finIncluse = fin.subtract(const Duration(days: 1));
        return "Semaine du ${DateFormat('d MMM', 'fr_FR').format(debut)} au ${DateFormat('d MMM yyyy', 'fr_FR').format(finIncluse)}";
      case _PeriodeRecap.mois:
        return DateFormat.yMMMM('fr_FR').format(debut).toUpperCase();
      case _PeriodeRecap.annee:
        return "${debut.year}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Store.I;
    final cfg = AppConfig.I;

    final (debut, fin) = _bornesPeriode();

    List<Map<String, dynamic>> occurrencesPeriode = [];

    for (DateTime d = debut; d.isBefore(fin); d = d.add(const Duration(days: 1))) {
      for (var o in s.ops.where((x) => x.banque == s.active)) {
        if (o.occursOn(d)) {
          occurrencesPeriode.add({
            'desc': o.desc,
            'montant': o.montant,
            'depense': o.depense,
          });
        }
      }
    }

    double totD = 0, totR = 0;
    for (final o in occurrencesPeriode) {
      if (o['depense']) {
        totD += o['montant'];
      } else {
        totR += o['montant'];
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Récapitulatif"),
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
                  children: _PeriodeRecap.values.map((p) {
                    final selected = _periode == p;
                    const labels = {
                      _PeriodeRecap.jour: "Jour",
                      _PeriodeRecap.semaine: "Semaine",
                      _PeriodeRecap.mois: "Mois",
                      _PeriodeRecap.annee: "Année",
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
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCol("Recettes", totR, Colors.green, cfg.currency),
                _statCol("Dépenses", totD, Colors.red, cfg.currency),
                _statCol(
                  "Évolution",
                  totR - totD,
                  (totR - totD) >= 0 ? Colors.blue : Colors.orange,
                  cfg.currency,
                ),
              ],
            ),
          ),
          Expanded(
            child: occurrencesPeriode.isEmpty
                ? const Center(child: Text("Aucune opération sur cette période"))
                : Row(
                    children: [
                      Expanded(
                        child: ListView(
                          children: occurrencesPeriode
                              .where((o) => !o['depense'])
                              .map((o) => _itemRow(o, Colors.green, cfg.currency))
                              .toList(),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: ListView(
                          children: occurrencesPeriode
                              .where((o) => o['depense'])
                              .map((o) => _itemRow(o, Colors.red, cfg.currency))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(Map<String, dynamic> o, Color color, String currency) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              o['desc'],
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            "${o['montant'].toStringAsFixed(2)} $currency",
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String t, double v, Color c, String cur) => Column(
        children: [
          Text(t, style: const TextStyle(fontSize: 10)),
          Text(
            "${v.toStringAsFixed(2)} $cur",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c),
          ),
        ],
      );
}
