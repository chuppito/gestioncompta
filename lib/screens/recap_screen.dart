import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:intl/intl.dart';
import '../services/store.dart';
import '../services/app_config.dart';


class Recap extends StatefulWidget {
  const Recap({super.key});

  @override
  State<Recap> createState() => _RecapState();
}

class _RecapState extends State<Recap> {
  DateTime moisAffiche = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final s = Store.I;
    final cfg = AppConfig.I;

    List<Map<String, dynamic>> occurrencesMois = [];

    DateTime debut = DateTime(moisAffiche.year, moisAffiche.month, 1);
    DateTime fin = DateTime(moisAffiche.year, moisAffiche.month + 1, 0);

    for (DateTime d = debut;
        d.isBefore(fin.add(const Duration(days: 1)));
        d = d.add(const Duration(days: 1))) {
      for (var o in s.ops.where((x) => x.banque == s.active)) {
        if (o.occursOn(d)) {
          occurrencesMois.add({
            'desc': o.desc,
            'montant': o.montant,
            'depense': o.depense,
          });
        }
      }
    }

    double totD = 0, totR = 0;
    for (final o in occurrencesMois) {
      if (o['depense']) {
        totD += o['montant'];
      } else {
        totR += o['montant'];
      }
    }

    final nomMois = DateFormat.yMMMM('fr_FR').format(moisAffiche);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Récapitulatif"),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() =>
                    moisAffiche = DateTime(moisAffiche.year, moisAffiche.month - 1)),
              ),
              Text(
                nomMois.toUpperCase(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() =>
                    moisAffiche = DateTime(moisAffiche.year, moisAffiche.month + 1)),
              ),
            ],
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
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    children: occurrencesMois
                        .where((o) => !o['depense'])
                        .map((o) => _itemRow(o, Colors.green, cfg.currency))
                        .toList(),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: ListView(
                    children: occurrencesMois
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
