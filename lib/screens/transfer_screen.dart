import 'package:flutter/material.dart';
import '../services/store.dart';
import '../theme.dart';

class TransferScreen extends StatefulWidget {
  final DateTime date;
  const TransferScreen({super.key, required this.date});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  String? from;
  String? to;
  final amount = TextEditingController();
  final desc = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final s = Store.I;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Transfert"),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "De"),
              items: s.banques
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) => setState(() => from = v),
            ),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "Vers"),
              items: s.banques
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) => setState(() => to = v),
            ),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: "Montant"),
            ),
            TextField(
              controller: desc,
              decoration: const InputDecoration(labelText: "Description"),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (from == null || to == null || from == to) return;
                  if (amount.text.isEmpty) return;

                  s.transfer(
                    from: from!,
                    to: to!,
                    montant: double.parse(amount.text.replaceAll(',', '.')),
                    desc: desc.text,
                    date: widget.date,
                  );

                  Navigator.pop(context);
                },
                child: const Text("Valider le transfert"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
