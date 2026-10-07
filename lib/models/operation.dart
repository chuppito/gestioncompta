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

  /// Re-pointe le passé sans modifier les dépointages futurs.
  void autoPointPast(DateTime until) {
    final limit = DateTime(until.year, until.month, until.day);
    pointages.removeWhere((key) {
      final day = DateTime.tryParse(key);
      return day != null && !day.isAfter(limit) && occursOn(day);
    });
  }

  /// Parcourt les dates du calendrier en conservant le jour de départ.
  /// Une échéance le 31 reste absente des mois sans 31, comme occursOn.
  Iterable<DateTime> occurrencesUntil(DateTime until) sync* {
    final limit = DateTime(until.year, until.month, until.day);
    final end = finRecurrence;
    final last = end != null && end.isBefore(limit)
        ? DateTime(end.year, end.month, end.day)
        : limit;
    if (f == Frequence.ponctuel) {
      if (!dateJour.isAfter(last) && occursOn(dateJour)) yield dateJour;
      return;
    }
    if (f == Frequence.jour || f == Frequence.semaine) {
      final step = f == Frequence.jour ? 1 : 7;
      for (
        var day = dateJour;
        !day.isAfter(last);
        day = DateTime(day.year, day.month, day.day + step)
      ) {
        if (occursOn(day)) yield day;
      }
      return;
    }
    final step = switch (f) {
      Frequence.trimestre => 3,
      Frequence.semestre => 6,
      Frequence.an => 12,
      _ => 1,
    };
    for (var offset = 0; ; offset += step) {
      final month = DateTime(date.year, date.month + offset);
      if (month.isAfter(last)) break;
      final day = DateTime(month.year, month.month, date.day);
      if (day.month == month.month && !day.isAfter(last) && occursOn(day)) {
        yield day;
      }
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

