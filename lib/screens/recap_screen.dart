import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:intl/intl.dart';
import '../services/store.dart';
import '../services/app_config.dart';
import '../models/operation.dart';

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

    // On génère les occurrences opération par opération au lieu de tester
    // chaque opération pour chaque jour. Pour une année, cela évite des
    // dizaines de milliers d'appels à occursOn()/DateFormat().
    final occurrencesPeriode = <Map<String, dynamic>>[];

    void ajouterOccurrence(dynamic o, DateTime d) {
      final jour = DateTime(d.year, d.month, d.day);
      if (jour.isBefore(debut) || !jour.isBefore(fin)) return;
      final cle = '${jour.year.toString().padLeft(4, '0')}-'
          '${jour.month.toString().padLeft(2, '0')}-'
          '${jour.day.toString().padLeft(2, '0')}';
      if (o.exclusions.contains(cle)) return;

      occurrencesPeriode.add({
        'desc': o.desc,
        'montant': o.montant,
        'depense': o.depense,
      });
    }

    for (final o in s.ops) {
      if (o.banque != s.active) continue;
      if (o.dateJour.isAfter(fin.subtract(const Duration(days: 1)))) continue;
      if (o.finRecurrence != null && o.finRecurrence!.isBefore(debut)) continue;

      switch (o.f) {
        case Frequence.ponctuel:
          ajouterOccurrence(o, o.dateJour);
          break;

        case Frequence.jour:
          var d = o.dateJour.isAfter(debut) ? o.dateJour : debut;
          while (d.isBefore(fin) &&
              (o.finRecurrence == null || !d.isAfter(o.finRecurrence!))) {
            ajouterOccurrence(o, d);
            d = d.add(const Duration(days: 1));
          }
          break;

        case Frequence.semaine:
          var d = o.dateJour.isAfter(debut) ? o.dateJour : debut;
          final decalage = (o.date.weekday - d.weekday + 7) % 7;
          d = d.add(Duration(days: decalage));
          while (d.isBefore(fin) &&
              (o.finRecurrence == null || !d.isAfter(o.finRecurrence!))) {
            ajouterOccurrence(o, d);
            d = d.add(const Duration(days: 7));
          }
          break;

        case Frequence.mois:
        case Frequence.trimestre:
        case Frequence.semestre:
          final pas = o.f == Frequence.mois
              ? 1
              : (o.f == Frequence.trimestre ? 3 : 6);
          var mois = DateTime(
            debut.year,
            debut.month,
            1,
          );
          final premiereOccurrence = o.dateJour.isAfter(mois)
              ? o.dateJour
              : mois;
          mois = DateTime(
            premiereOccurrence.year,
            premiereOccurrence.month,
            1,
          );

          while (mois.isBefore(fin)) {
            final moisDepuisOrigine =
                (mois.year - o.date.year) * 12 + mois.month - o.date.month;
            if (moisDepuisOrigine >= 0 && moisDepuisOrigine % pas == 0) {
              // occursOn() n'accepte que les mois ayant exactement le même
              // numéro de jour que l'opération d'origine.
              final d = DateTime(mois.year, mois.month, o.date.day);
              if (d.month == mois.month) {
                ajouterOccurrence(o, d);
              }
            }
            mois = DateTime(mois.year, mois.month + 1, 1);
          }
          break;

        case Frequence.an:
          var an = debut.year;
          if (an < o.date.year) an = o.date.year;
          while (an <= fin.year) {
            final d = DateTime(an, o.date.month, o.date.day);
            if (d.year == an &&
                !d.isBefore(debut) &&
                d.isBefore(fin) &&
                (o.finRecurrence == null || !d.isAfter(o.finRecurrence!))) {
              ajouterOccurrence(o, d);
            }
            an++;
          }
          break;
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
