import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:table_calendar/table_calendar.dart';

import '../services/store.dart';
import '../services/app_config.dart';
import '../models/operation.dart';

import 'saisie_screen.dart';
import 'recap_screen.dart';
import 'nouvelle_vente_screen.dart';
import 'vente_detail_screen.dart';


class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

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

    final activeBank = s.active;

    final opsDuJour = (activeBank == null)
        ? <Operation>[]
        : s.ops
            .where((o) => o.banque == activeBank && o.occursOn(_selectedDay))
            .toList();

    final soldeReel = s.getSoldeAu(_selectedDay, false);
    final soldePointe = s.getSoldeAu(_selectedDay, true);

    return Scaffold(
      appBar: AppBar(
        title: activeBank == null
            ? const Text("Gestion Compta")
            : DropdownButton<String>(
                value: activeBank,
                dropdownColor: kPrimary,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                underline: const SizedBox(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                items: s.banques
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    s.active = val;
                    s.save();
                  });
                },
              ),
        backgroundColor: kPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: "Récapitulatif",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Recap()),
              ).then((_) => setState(() {}));
            },
          ),
        ],
      ),
      body: activeBank == null
          ? _aucunCompte(context, s)
          : Column(
              children: [
                TableCalendar(
                  firstDay: DateTime(2023),
                  lastDay: DateTime(2035),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  locale: 'fr_FR',
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                  ),
                  calendarStyle: const CalendarStyle(
                    selectedDecoration: BoxDecoration(
                      color: kPrimary,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: kSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) =>
                      setState(() => _calendarFormat = format),
                  onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                  eventLoader: (_) => [],
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      return _buildDay(day, activeBank, false);
                    },
                    todayBuilder: (context, day, focusedDay) {
                      return Container(
                        decoration: const BoxDecoration(
                          color: kSecondary,
                          shape: BoxShape.circle,
                        ),
                        child: _buildDay(day, activeBank, true, white: true),
                      );
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      return Container(
                        decoration: const BoxDecoration(
                          color: kPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: _buildDay(day, activeBank, true, white: true),
                      );
                    },
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: Colors.grey.shade200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _soldeWidget("Solde Réel", soldeReel, cfg.currency),
                      _soldeWidget("Solde Pointé", soldePointe, cfg.currency),
                    ],
                  ),
                ),
                Expanded(
                  child: opsDuJour.isEmpty
                      ? const Center(child: Text("Aucune opération"))
                      : ListView.builder(
                          itemCount: opsDuJour.length,
                          itemBuilder: (context, index) {
                            final op = opsDuJour[index];
                            final isPointed = op.isPointed(_selectedDay);
                            final color =
                                op.depense ? Colors.red : Colors.green;
                            final prefix = op.depense ? "-" : "+";

                            return ListTile(
                              leading: IconButton(
                                icon: Icon(
                                  isPointed
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color:
                                      isPointed ? Colors.green : Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    s.togglePointage(op, _selectedDay);
                                  });
                                },
                              ),
                              title: Text(op.desc),
                              subtitle: op.venteId != null
                                  ? const Text(
                                      "Vente (voir onglet Ventes)",
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blueGrey),
                                    )
                                  : (op.f != Frequence.ponctuel
                                      ? Text(
                                          "[${_getFreqLabel(op.f)}]",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.blueGrey,
                                          ),
                                        )
                                      : null),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "$prefix${op.montant.toStringAsFixed(2)} ${cfg.currency}",
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () =>
                                        _supprimerOperation(context, s, op),
                                  ),
                                ],
                              ),
                              onTap: op.venteId != null
                                  ? () {
                                      final matches = s.ventes
                                          .where((v) => v.id == op.venteId);
                                      if (matches.isEmpty) return;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => VenteDetailScreen(
                                            vente: matches.first,
                                          ),
                                        ),
                                      ).then((_) => setState(() {}));
                                    }
                                  : () => _modifierOperation(context, s, op),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: activeBank == null
          ? null
          : FloatingActionButton(
              backgroundColor: kPrimary,
              child: const Icon(Icons.add),
              onPressed: () => _ouvrirMenuAjout(context),
            ),
    );
  }

  Widget _aucunCompte(BuildContext context, Store s) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Aucun compte configuré"),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _creerCompte(context, s),
            child: const Text("Créer un compte"),
          ),
        ],
      ),
    );
  }

  void _creerCompte(BuildContext context, Store s) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nouveau compte"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Ex : Caisse, Banque"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              setState(() {
                s.banques.add(name);
                s.active = name;
                s.save();
              });
              Navigator.pop(ctx);
            },
            child: const Text("Créer"),
          ),
        ],
      ),
    );
  }

  void _ouvrirMenuAjout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.point_of_sale, color: kPrimary),
              title: const Text("Nouvelle vente"),
              subtitle: const Text("Choisir des articles + mode de paiement"),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        NouvelleVenteScreen(dateInitiale: _selectedDay),
                  ),
                ).then((_) => setState(() {}));
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note, color: kPrimary),
              title: const Text("Opération manuelle"),
              subtitle: const Text("Recette ou dépense libre (ex: courses)"),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Saisie(dateSelectionnee: _selectedDay),
                  ),
                ).then((_) => setState(() {}));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _modifierOperation(BuildContext context, Store s, Operation op) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Saisie(op: op, dateSelectionnee: _selectedDay),
      ),
    ).then((_) => setState(() {}));
  }

  Widget _buildDay(
    DateTime day,
    String? activeBank,
    bool isSelected, {
    bool white = false,
  }) {
    final s = Store.I;

    final hasOperation =
        activeBank != null && s.opsActives().any((o) => o.occursOn(day));

    final solde =
        (activeBank == null || !hasOperation) ? 0.0 : s.getSoldeAu(day, false);

    final textColor =
        white ? Colors.white : (solde >= 0 ? Colors.green : Colors.red);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "${day.day}",
            style: TextStyle(
              fontSize: 14,
              color: white ? Colors.white : Colors.black,
            ),
          ),
          if (hasOperation)
            Text(
              solde.round().toString(),
              style: TextStyle(
                fontSize: 10,
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _soldeWidget(String titre, double valeur, String devise) {
    final color = valeur >= 0 ? Colors.green : Colors.red;
    return Column(
      children: [
        Text(titre),
        Text(
          "${valeur.toStringAsFixed(2)} $devise",
          style: TextStyle(color: color),
        ),
      ],
    );
  }

  String _getFreqLabel(Frequence f) {
    const labels = [
      "Ponctuel",
      "Quotidien",
      "Hebdomadaire",
      "Mensuel",
      "Trimestriel",
      "Semestriel",
      "Annuel",
    ];
    return (f.index >= 0 && f.index < labels.length) ? labels[f.index] : "";
  }

  void _supprimerOperation(BuildContext context, Store s, Operation op) {
    if (op.venteId != null) {
      _confirmerSuppressionVente(context, s, op);
      return;
    }

    if (op.f == Frequence.ponctuel) {
      setState(() {
        s.removeById(op.id);
      });
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer"),
        content: const Text("Que souhaitez-vous supprimer ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              s.deleteOccurrence(op, _selectedDay);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text("Cette occurrence"),
          ),
          TextButton(
            onPressed: () {
              s.deleteFrom(op, _selectedDay);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text("Celle-ci et les suivantes"),
          ),
          TextButton(
            onPressed: () {
              s.removeById(op.id);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text("Toutes"),
          ),
        ],
      ),
    );
  }

  void _confirmerSuppressionVente(BuildContext context, Store s, Operation op) {
    final correspondantes = s.ventes.where((v) => v.id == op.venteId);
    final vente = correspondantes.isEmpty ? null : correspondantes.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer cette vente ?"),
        content: Text(
          vente != null
              ? "${vente.label} et la recette associée dans le calendrier seront supprimées."
              : "Cette opération et la vente associée seront supprimées.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              if (vente != null) {
                s.deleteVente(vente);
              } else {
                // Vente introuvable (déjà supprimée) : on nettoie l'opération
                // orpheline restée dans le calendrier.
                s.removeById(op.id);
              }
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
  }
}
