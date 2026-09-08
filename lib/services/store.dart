import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/operation.dart';
import '../models/produit.dart';
import '../models/vente.dart';
import 'sync_service.dart';

class Store extends ChangeNotifier {
  static final Store I = Store._();
  Store._() {
    _load();
  }

  final box = Hive.box("db");

  List<String> banques = [];
  List<Operation> ops = [];
  List<Produit> produits = [];
  List<Vente> ventes = [];
  String? active;

  // ===================== SYNCHRONISATION CLOUD =====================
  // Permet de retrouver les mêmes données en se reconnectant avec le même
  // compte depuis un autre téléphone (même principe que l'app Fidélité).

  StreamSubscription? _cloudSubscription;
  DateTime? _lastLocalWrite;
  static const int _syncProtectionMs = 3000;

  void _load() {
    banques = List<String>.from(box.get("banques") ?? []);
    active = box.get("active");

    final rawOps = box.get("ops");
    ops = (rawOps is List)
        ? rawOps
            .whereType<Map>()
            .map((x) => Operation.fromMap(Map<String, dynamic>.from(x)))
            .toList()
        : [];

    final rawProduits = box.get("produits");
    produits = (rawProduits is List)
        ? rawProduits
            .whereType<Map>()
            .map((x) => Produit.fromMap(Map<String, dynamic>.from(x)))
            .toList()
        : [];

    final rawVentes = box.get("ventes");
    ventes = (rawVentes is List)
        ? rawVentes
            .whereType<Map>()
            .map((x) => Vente.fromMap(Map<String, dynamic>.from(x)))
            .toList()
        : [];

    if (active == null && banques.isNotEmpty) {
      active = banques.first;
    }
  }

  Map<String, dynamic> _toCloudMap() => {
        "banques": banques,
        "active": active,
        "ops": ops.map((x) => x.toMap()).toList(),
        "produits": produits.map((x) => x.toMap()).toList(),
        "ventes": ventes.map((x) => x.toMap()).toList(),
      };

  void _applyCloudMap(Map<String, dynamic> data) {
    banques = List<String>.from(data["banques"] ?? []);
    active = data["active"];
    ops = (data["ops"] as List? ?? [])
        .whereType<Map>()
        .map((x) => Operation.fromMap(Map<String, dynamic>.from(x)))
        .toList();
    produits = (data["produits"] as List? ?? [])
        .whereType<Map>()
        .map((x) => Produit.fromMap(Map<String, dynamic>.from(x)))
        .toList();
    ventes = (data["ventes"] as List? ?? [])
        .whereType<Map>()
        .map((x) => Vente.fromMap(Map<String, dynamic>.from(x)))
        .toList();

    box.put("banques", banques);
    box.put("active", active);
    box.put("ops", ops.map((x) => x.toMap()).toList());
    box.put("produits", produits.map((x) => x.toMap()).toList());
    box.put("ventes", ventes.map((x) => x.toMap()).toList());

    notifyListeners();
  }

  /// À appeler juste après la connexion : récupère les données du compte
  /// (si elles existent déjà sur un autre téléphone) et démarre l'écoute
  /// temps réel. Si le cloud est vide (premier lancement sur ce compte),
  /// on pousse simplement les données locales actuelles.
  Future<void> syncOnLogin() async {
    final cloudData = await SyncService.pullFromCloud();
    if (cloudData != null && cloudData.isNotEmpty) {
      _applyCloudMap(cloudData);
    } else {
      await SyncService.pushToCloud(_toCloudMap());
    }
    startRealtimeSync();
  }

  void startRealtimeSync() {
    _cloudSubscription?.cancel();
    _cloudSubscription = SyncService.listenToCloud((data) {
      // Si on vient d'écrire localement, on ignore cet écho pour ne pas
      // s'auto-écraser (même garde-fou que dans l'app Fidélité).
      if (_lastLocalWrite != null) {
        final elapsed = DateTime.now().difference(_lastLocalWrite!).inMilliseconds;
        if (elapsed < _syncProtectionMs) return;
      }
      _applyCloudMap(data);
    });
  }

  void stopRealtimeSync() {
    _cloudSubscription?.cancel();
    _cloudSubscription = null;
  }

  void save() {
    box.put("banques", banques);
    box.put("active", active);
    box.put("ops", ops.map((x) => x.toMap()).toList());
    box.put("produits", produits.map((x) => x.toMap()).toList());
    box.put("ventes", ventes.map((x) => x.toMap()).toList());
    _lastLocalWrite = DateTime.now();
    SyncService.pushToCloud(_toCloudMap());
    notifyListeners();
  }

  // ===================== OPERATIONS =====================

  void removeById(String id) {
    ops.removeWhere((o) => o.id == id);
    save();
  }

  List<Operation> opsActives() {
    if (active == null) return [];
    return ops.where((o) => o.banque == active).toList();
  }

  double getSoldeAu(DateTime cible, bool seulementPointe) {
    double total = 0;
    final jour = DateTime(cible.year, cible.month, cible.day);

    for (final o in opsActives()) {
      switch (o.f) {
        case Frequence.ponctuel:
          if (!o.dateJour.isAfter(jour)) {
            if (seulementPointe && !o.isPointed(o.dateJour)) continue;
            total += o.depense ? -o.montant : o.montant;
          }
          break;

        case Frequence.jour:
          DateTime d = o.dateJour;
          while (!d.isAfter(jour)) {
            if (o.occursOn(d)) {
              if (!seulementPointe || o.isPointed(d)) {
                total += o.depense ? -o.montant : o.montant;
              }
            }
            d = d.add(const Duration(days: 1));
          }
          break;

        default:
          DateTime d = o.dateJour;
          while (!d.isAfter(jour)) {
            if (o.occursOn(d)) {
              if (!seulementPointe || o.isPointed(d)) {
                total += o.depense ? -o.montant : o.montant;
              }
            }
            d = DateTime(d.year, d.month + 1, d.day);
          }
      }
    }

    return total;
  }

  void togglePointage(Operation op, DateTime day) {
    op.togglePointage(day);
    save();
  }

  /// Pointer le passé : re-pointe tout (vide les dépointages)
  void autoPointAllPast() {
    for (final o in opsActives()) {
      o.pointages.clear();
    }
    save();
  }

  void deleteOccurrence(Operation op, DateTime day) {
    final key =
        DateTime(day.year, day.month, day.day).toIso8601String().substring(0, 10);
    op.exclusions.add(key);
    save();
  }

  void deleteFrom(Operation op, DateTime day) {
    final veille =
        DateTime(day.year, day.month, day.day).subtract(const Duration(days: 1));
    op.finRecurrence = veille;
    save();
  }

  // ===================== PRODUITS =====================

  void addProduit(Produit p) {
    produits.add(p);
    save();
  }

  void updateProduit(Produit p) {
    final i = produits.indexWhere((x) => x.id == p.id);
    if (i != -1) produits[i] = p;
    save();
  }

  void removeProduit(String id) {
    produits.removeWhere((p) => p.id == id);
    save();
  }

  // ===================== VENTES =====================

  List<Vente> ventesActives() {
    if (active == null) return [];
    final list = ventes.where((v) => v.banque == active).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Enregistre une vente : calcule le numéro séquentiel du jour pour ce
  /// mode de paiement, crée le libellé (ex: CB_26_07_2026_01), génère
  /// l'opération de recette correspondante dans le calendrier compta.
  Vente enregistrerVente({
    required DateTime date,
    required ModePaiement mode,
    required List<VenteItem> items,
  }) {
    final jour = DateTime(date.year, date.month, date.day);

    final dejaMeme = ventes.where((v) =>
        v.banque == active && v.mode == mode && isSameDay(v.date, jour));
    final numero = dejaMeme.length + 1;

    final label =
        "${mode.prefixe}_${_pad2(jour.day)}_${_pad2(jour.month)}_${jour.year}_${numero.toString().padLeft(2, '0')}";

    final total = items.fold<double>(0, (s, i) => s + i.sousTotal);

    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final operation = Operation(
      id: id,
      desc: label,
      montant: total,
      depense: false,
      date: jour,
      banque: active!,
      f: Frequence.ponctuel,
      venteId: id,
    );

    final vente = Vente(
      id: id,
      date: jour,
      mode: mode,
      numero: numero,
      label: label,
      items: items,
      total: total,
      banque: active!,
      operationId: id,
    );

    ops.add(operation);
    ventes.add(vente);
    save();

    return vente;
  }

  void deleteVente(Vente v) {
    ventes.removeWhere((x) => x.id == v.id);
    if (v.operationId != null) {
      ops.removeWhere((o) => o.id == v.operationId);
    }
    save();
  }

  /// Met à jour une vente existante (date, mode, articles) et synchronise
  /// l'opération de recette liée dans le calendrier.
  void updateVente({
    required Vente vente,
    required DateTime date,
    required ModePaiement mode,
    required List<VenteItem> items,
  }) {
    final jour = DateTime(date.year, date.month, date.day);
    final total = items.fold<double>(0, (s, i) => s + i.sousTotal);

    final dateChanged = !isSameDay(vente.date, jour);
    final modeChanged = vente.mode != mode;

    if (dateChanged || modeChanged) {
      final autres = ventes.where((v) =>
          v.id != vente.id &&
          v.banque == vente.banque &&
          v.mode == mode &&
          isSameDay(v.date, jour));
      vente.numero = autres.length + 1;
      vente.label =
          "${mode.prefixe}_${_pad2(jour.day)}_${_pad2(jour.month)}_${jour.year}_${vente.numero.toString().padLeft(2, '0')}";
    }

    vente.date = jour;
    vente.mode = mode;
    vente.items = items;
    vente.total = total;

    if (vente.operationId != null) {
      final idx = ops.indexWhere((o) => o.id == vente.operationId);
      if (idx != -1) {
        ops[idx].desc = vente.label;
        ops[idx].montant = total;
        ops[idx].date = jour;
      }
    }

    save();
  }

  // ===================== IMPORT PAYPAL =====================

  /// Numéros de reçu déjà importés (pour l'écran d'aperçu, avant même de
  /// lancer l'import).
  Set<String> refsExternesExistantes() =>
      ventes.map((v) => v.refExterne).whereType<String>().toSet();

  /// Importe un lot de reçus PayPal. Les reçus dont la référence existe déjà
  /// (`refExterne`) sont ignorés silencieusement (pas de doublon), les
  /// autres deviennent une Vente (mode PayPal) + une Operation de recette.
  ImportPaypalResult importerPayPal(List<PayPalRecu> recus) {
    if (active == null) {
      return ImportPaypalResult(total: recus.length, dejaImportes: 0, nouveaux: 0, montant: 0);
    }

    final existants = refsExternesExistantes();
    int dejaImportes = 0;
    double montant = 0;
    final nouvellesVentes = <Vente>[];
    final nouvellesOps = <Operation>[];

    for (final r in recus) {
      if (existants.contains(r.refExterne)) {
        dejaImportes++;
        continue;
      }

      final jour = DateTime(r.date.year, r.date.month, r.date.day);

      final dejaMemeJour = ventes
              .where((v) =>
                  v.banque == active &&
                  v.mode == ModePaiement.paypal &&
                  isSameDay(v.date, jour))
              .length +
          nouvellesVentes.where((v) => isSameDay(v.date, jour)).length;
      final numero = dejaMemeJour + 1;

      final label =
          "PAYPAL_${_pad2(jour.day)}_${_pad2(jour.month)}_${jour.year}_${numero.toString().padLeft(2, '0')}";

      final total = r.items.fold<double>(0, (s, i) => s + i.sousTotal);
      final id = r.refExterne; // déjà unique, ex: "paypal_4581"

      final operation = Operation(
        id: id,
        desc: label,
        montant: total,
        depense: false,
        date: jour,
        banque: active!,
        f: Frequence.ponctuel,
        venteId: id,
      );

      final vente = Vente(
        id: id,
        date: jour,
        mode: ModePaiement.paypal,
        numero: numero,
        label: label,
        items: r.items,
        total: total,
        banque: active!,
        operationId: id,
        source: "paypal",
        refExterne: r.refExterne,
      );

      nouvellesVentes.add(vente);
      nouvellesOps.add(operation);
      existants.add(r.refExterne);
      montant += total;
    }

    ventes.addAll(nouvellesVentes);
    ops.addAll(nouvellesOps);
    if (nouvellesVentes.isNotEmpty) save();

    return ImportPaypalResult(
      total: recus.length,
      dejaImportes: dejaImportes,
      nouveaux: nouvellesVentes.length,
      montant: montant,
    );
  }

  String _pad2(int n) => n.toString().padLeft(2, '0');
}

/// Un reçu PayPal (regroupement de lignes ayant le même n° de reçu) prêt à
/// être importé.
class PayPalRecu {
  final String refExterne; // ex: "paypal_4581"
  final DateTime date;
  final List<VenteItem> items;

  PayPalRecu({required this.refExterne, required this.date, required this.items});
}

class ImportPaypalResult {
  final int total;
  final int dejaImportes;
  final int nouveaux;
  final double montant;

  ImportPaypalResult({
    required this.total,
    required this.dejaImportes,
    required this.nouveaux,
    required this.montant,
  });
}
