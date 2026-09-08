import 'package:flutter/material.dart';
import '../theme.dart';

import '../services/store.dart';
import '../services/app_config.dart';
import '../models/operation.dart';


class Saisie extends StatefulWidget {
  final Operation? op;
  final DateTime dateSelectionnee;

  const Saisie({
    super.key,
    this.op,
    required this.dateSelectionnee,
  });

  @override
  State<Saisie> createState() => _SaisieState();
}

class _SaisieState extends State<Saisie> {
  final _descCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();
  final _montantFocus = FocusNode();

  bool _depense = true;
  Frequence _frequence = Frequence.ponctuel;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = widget.dateSelectionnee;

    if (widget.op != null) {
      final op = widget.op!;
      _descCtrl.text = op.desc;
      _montantCtrl.text = op.montant.toStringAsFixed(2);
      _depense = op.depense;
      _frequence = op.f;
      _date = op.f == Frequence.ponctuel ? op.date : widget.dateSelectionnee;
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _montantCtrl.dispose();
    _montantFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = AppConfig.I;
    final isEdit = widget.op != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Modifier l'opération" : "Nouvelle opération"),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
            ),
            if (!isEdit) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.shopping_cart, size: 18, color: kPrimary),
                    label: const Text("Achat METRO"),
                    onPressed: () {
                      setState(() {
                        _descCtrl.text = "Achat METRO";
                        _depense = true;
                        _frequence = Frequence.ponctuel;
                        _date = DateTime.now();
                      });
                      _montantFocus.requestFocus();
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.account_balance, size: 18, color: kPrimary),
                    label: const Text("Cotisations URSSAF"),
                    onPressed: () {
                      setState(() {
                        _descCtrl.text = "Cotisations URSSAF";
                        _depense = true;
                        _frequence = Frequence.ponctuel;
                        _date = DateTime.now();
                      });
                      _montantFocus.requestFocus();
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _montantCtrl,
              focusNode: _montantFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "Montant",
                suffixText: cfg.currency,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _depense = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            _depense ? Colors.red.shade50 : Colors.transparent,
                        border: Border.all(
                          color: _depense ? Colors.red : Colors.grey.shade300,
                          width: _depense ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.remove_circle_outline,
                              color: _depense ? Colors.red : Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            "Dépense",
                            style: TextStyle(
                              color: _depense ? Colors.red : Colors.grey,
                              fontWeight:
                                  _depense ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _depense = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_depense
                            ? Colors.green.shade50
                            : Colors.transparent,
                        border: Border.all(
                          color: !_depense ? Colors.green : Colors.grey.shade300,
                          width: !_depense ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline,
                              color: !_depense ? Colors.green : Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            "Recette",
                            style: TextStyle(
                              color: !_depense ? Colors.green : Colors.grey,
                              fontWeight: !_depense
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                "${_date.day.toString().padLeft(2, '0')}/"
                "${_date.month.toString().padLeft(2, '0')}/"
                "${_date.year}",
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Frequence>(
              initialValue: _frequence,
              decoration: const InputDecoration(
                labelText: "Fréquence",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: Frequence.ponctuel, child: Text("Une fois")),
                DropdownMenuItem(
                    value: Frequence.jour, child: Text("Quotidien")),
                DropdownMenuItem(
                    value: Frequence.semaine, child: Text("Hebdomadaire")),
                DropdownMenuItem(
                    value: Frequence.mois, child: Text("Mensuel")),
                DropdownMenuItem(
                    value: Frequence.trimestre, child: Text("Trimestriel")),
                DropdownMenuItem(
                    value: Frequence.semestre, child: Text("Semestriel")),
                DropdownMenuItem(
                    value: Frequence.an, child: Text("Annuel")),
              ],
              onChanged: (v) => setState(() => _frequence = v!),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _valider,
                child: const Text("Enregistrer", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _valider() {
    final s = Store.I;
    final desc = _descCtrl.text.trim();
    final montant = double.tryParse(_montantCtrl.text.replaceAll(',', '.'));

    if (desc.isEmpty || montant == null || montant <= 0) return;
    if (s.active == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (widget.op != null) {
      final op = widget.op!;

      if (op.f == Frequence.ponctuel) {
        op.desc = desc;
        op.montant = montant;
        op.depense = _depense;
        op.date = _date;
        op.f = _frequence;
        s.syncOperationModifiee(op);
        Navigator.pop(context);
      } else {
        final occurrenceDay = DateTime(
          widget.dateSelectionnee.year,
          widget.dateSelectionnee.month,
          widget.dateSelectionnee.day,
        );
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Modifier"),
            content: const Text("Que souhaitez-vous modifier ?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Annuler"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _modifierOccurrence(s, op, occurrenceDay, desc, montant, today);
                  Navigator.pop(context);
                },
                child: const Text("Cette occurrence"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _modifierDepuis(s, op, occurrenceDay, desc, montant, today);
                  Navigator.pop(context);
                },
                child: const Text("Celle-ci et les suivantes"),
              ),
            ],
          ),
        );
      }
    } else {
      final op = Operation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        desc: desc,
        montant: montant,
        depense: _depense,
        date: _date,
        banque: s.active!,
        f: _frequence,
        pointages: [],
      );

      s.addOperation(op);
      Navigator.pop(context);
    }
  }

  void _modifierOccurrence(
    Store s,
    Operation op,
    DateTime occurrenceDay,
    String desc,
    double montant,
    DateTime today,
  ) {
    s.deleteOccurrence(op, occurrenceDay);

    final newOp = Operation(
      id: '${DateTime.now().millisecondsSinceEpoch}_occ',
      desc: desc,
      montant: montant,
      depense: _depense,
      date: _date,
      banque: op.banque,
      f: Frequence.ponctuel,
      pointages: [],
    );

    final newDay = DateTime(_date.year, _date.month, _date.day);
    if (!newDay.isAfter(today)) {
      newOp.togglePointage(newDay);
    }

    s.addOperation(newOp);
  }

  void _modifierDepuis(
    Store s,
    Operation op,
    DateTime occurrenceDay,
    String desc,
    double montant,
    DateTime today,
  ) {
    s.deleteFrom(op, occurrenceDay);

    final newOp = Operation(
      id: '${DateTime.now().millisecondsSinceEpoch}_from',
      desc: desc,
      montant: montant,
      depense: _depense,
      date: occurrenceDay,
      banque: op.banque,
      f: _frequence,
      pointages: [],
    );

    newOp.autoPointPast(today);

    s.addOperation(newOp);
  }
}
