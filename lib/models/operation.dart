import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

enum Frequence {
  ponctuel,
  jour,
  semaine,
  mois,
  trimestre,
  semestre,
  an,
}

class Operation {
  String id;
  String desc;
  double montant;
  bool depense;

  /// pointage par date (clé "yyyy-MM-dd")
  List<String> pointages;

  DateTime date;
  String banque;
  Frequence f;

  List<String> exclusions;

  /// suppression "occurrence + suivantes"
  DateTime? finRecurrence;

  bool transfert;
  String? banqueCible;

  /// Lien optionnel vers une Vente (si cette opération est une recette
  /// générée depuis l'onglet Ventes).
  String? venteId;

  Operation({
    required this.id,
    required this.desc,
    required this.montant,
    required this.depense,
    required this.date,
    required this.banque,
    List<String>? pointages,
    this.f = Frequence.ponctuel,
    List<String>? exclusions,
    this.finRecurrence,
    this.transfert = false,
    this.banqueCible,
    this.venteId,
  })  : pointages = pointages ?? [],
        exclusions = exclusions ?? [];

  DateTime get dateJour => DateTime(date.year, date.month, date.day);

  String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// pointages = liste des dates DEPOINTÉES
  bool isPointed(DateTime d) {
    if (!occursOn(d)) return false;
    return !pointages.contains(_key(d));
  }

  void togglePointage(DateTime d) {
    final k = _key(DateTime(d.year, d.month, d.day));
    if (pointages.contains(k)) {
      pointages.remove(k); // on recohe
    } else {
      pointages.add(k); // on décoche
    }
  }

  /// Pointe automatiquement toutes les occurrences passées jusqu'à [until]
  void autoPointPast(DateTime until) {
    final limit = DateTime(until.year, until.month, until.day);

    if (f == Frequence.ponctuel) {
      if (!dateJour.isAfter(limit)) {
        final k = _key(dateJour);
        if (!pointages.contains(k)) pointages.add(k);
      }
      return;
    }

    DateTime d = dateJour;
    while (!d.isAfter(limit)) {
      if (occursOn(d)) {
        final k = _key(d);
        if (!pointages.contains(k)) pointages.add(k);
      }
      d = _nextOccurrence(d);
    }
  }

  DateTime _nextOccurrence(DateTime d) {
    switch (f) {
      case Frequence.ponctuel:
        return d.add(const Duration(days: 1));
      case Frequence.jour:
        return d.add(const Duration(days: 1));
      case Frequence.semaine:
        return d.add(const Duration(days: 7));
      case Frequence.mois:
        return DateTime(d.year, d.month + 1, d.day);
      case Frequence.trimestre:
        return DateTime(d.year, d.month + 3, d.day);
      case Frequence.semestre:
        return DateTime(d.year, d.month + 6, d.day);
      case Frequence.an:
        return DateTime(d.year + 1, d.month, d.day);
    }
  }

  Map<String, dynamic> toMap() => {
        "id": id,
        "d": desc,
        "m": montant,
        "dep": depense,
        "dt": date.toIso8601String(),
        "b": banque,
        "f": f.index,
        "ex": exclusions,
        "pt": pointages,
        "fin": finRecurrence?.toIso8601String(),
        "tr": transfert,
        "bc": banqueCible,
        "vid": venteId,
      };

  factory Operation.fromMap(Map<String, dynamic> m) {
    return Operation(
      id: m["id"] ?? "",
      desc: m["d"] ?? "",
      montant: (m["m"] as num?)?.toDouble() ?? 0,
      depense: m["dep"] == true,
      date: DateTime.tryParse(m["dt"] ?? "") ?? DateTime.now(),
      banque: m["b"] ?? "",
      f: (m["f"] is int && m["f"] >= 0 && m["f"] < Frequence.values.length)
          ? Frequence.values[m["f"]]
          : Frequence.ponctuel,
      exclusions: (m["ex"] is List) ? List<String>.from(m["ex"]) : [],
      pointages: (m["pt"] is List) ? List<String>.from(m["pt"]) : [],
      finRecurrence: m["fin"] != null ? DateTime.tryParse(m["fin"]) : null,
      transfert: m["tr"] == true,
      banqueCible: m["bc"],
      venteId: m["vid"],
    );
  }

  bool occursOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final ex = _key(d);

    if (exclusions.contains(ex)) return false;

    if (finRecurrence != null && d.isAfter(finRecurrence!)) {
      return false;
    }

    if (dateJour.isAfter(d)) return false;

    switch (f) {
      case Frequence.ponctuel:
        return isSameDay(dateJour, d);

      case Frequence.jour:
        return true;

      case Frequence.semaine:
        return d.weekday == date.weekday;

      case Frequence.mois:
        return d.day == date.day;

      case Frequence.trimestre:
        return d.day == date.day && ((d.month - date.month) % 3 == 0);

      case Frequence.semestre:
        return d.day == date.day && ((d.month - date.month) % 6 == 0);

      case Frequence.an:
        return d.day == date.day && d.month == date.month;
    }
  }
}
