import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  List<PanierEnAttente> paniersEnAttente = [];
  String? active;

  // ===================== SYNCHRONISATION CLOUD =====================
  // Permet de retrouver les mêmes données en se reconnectant avec le même
  // compte depuis un autre téléphone (même principe que l'app Fidélité).
  //
  // Ventes et opérations sont désormais synchronisées individuellement
  // (1 document Firestore par vente/opération) plutôt que dans un seul gros
  // document : ça évite de dépasser la limite de 1 Mo par document dès
  // qu'il y a beaucoup de ventes (import PayPal notamment). On garde en
  // mémoire la dernière version connue de chaque vente/opération
  // ([_syncedVentes]/[_syncedOps]) pour ne pousser que ce qui a réellement
  // changé à chaque [save].

  StreamSubscription? _metaSub;
  DateTime? _lastLocalWrite;
  static const int _syncProtectionMs = 3000;

  Map<String, Map<String, dynamic>> _syncedVentes = {};
  Map<String, Map<String, dynamic>> _syncedOps = {};

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

    final rawAttentes = box.get("paniersEnAttente");
    paniersEnAttente = (rawAttentes is List)
        ? rawAttentes
            .whereType<Map>()
            .map((x) => PanierEnAttente.fromMap(Map<String, dynamic>.from(x)))
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

    // Le cache local sait déjà ce qui a été synchronisé la dernière fois :
    // ça permet, au prochain démarrage, de reconnaître les éléments qui
    // n'ont pas changé côté serveur et d'éviter de les retraiter pour rien
    // (voir startRealtimeSync).
    _syncedVentes = {for (final v in ventes) v.id: v.toMap()};
    _syncedOps = {for (final o in ops) o.id: o.toMap()};
  }

  Map<String, dynamic> _metaMap() => {
        "banques": banques,
        "active": active,
        "produits": produits.map((x) => x.toMap()).toList(),
        "paniersEnAttente": paniersEnAttente.map((x) => x.toMap()).toList(),
      };

  void _applyMeta(Map<String, dynamic> data) {
    banques = List<String>.from(data["banques"] ?? []);
    active = data["active"];
    produits = (data["produits"] as List? ?? [])
        .whereType<Map>()
        .map((x) => Produit.fromMap(Map<String, dynamic>.from(x)))
        .toList();
    paniersEnAttente = (data["paniersEnAttente"] as List? ?? [])
        .whereType<Map>()
        .map((x) => PanierEnAttente.fromMap(Map<String, dynamic>.from(x)))
        .toList();

    box.put("banques", banques);
    box.put("active", active);
    box.put("produits", produits.map((x) => x.toMap()).toList());
    box.put("paniersEnAttente", paniersEnAttente.map((x) => x.toMap()).toList());

    notifyListeners();
  }

  /// À appeler juste après la connexion : récupère les données du compte
  /// (si elles existent déjà sur un autre téléphone) et démarre l'écoute
  /// temps réel. Si le cloud est vide (premier lancement sur ce compte), on
  /// pousse simplement les données locales actuelles.
  Future<void> syncOnLogin() async {
    final meta = await SyncService.pullMeta();

    if (meta == null) {
      // Tout premier lancement sur ce compte : on pousse l'état local.
      await SyncService.pushMeta(_metaMap());
      await SyncService.batchSetVentes(ventes.map((v) => v.toMap()).toList());
      await SyncService.batchSetOps(ops.map((o) => o.toMap()).toList());
      _syncedVentes = {for (final v in ventes) v.id: v.toMap()};
      _syncedOps = {for (final o in ops) o.id: o.toMap()};
    } else if (meta["ventes"] is List || meta["ops"] is List) {
      // Migration : anciennes données où ventes/opérations étaient encore
      // dans le document "store" lui-même (avant qu'on sépare en
      // sous-collections pour éviter la limite de 1 Mo par document).
      debugPrint("Migration : déplacement des ventes/opérations vers des sous-collections...");

      final ventesLegacy = (meta["ventes"] as List? ?? [])
          .whereType<Map>()
          .map((x) => Vente.fromMap(Map<String, dynamic>.from(x)))
          .toList();
      final opsLegacy = (meta["ops"] as List? ?? [])
          .whereType<Map>()
          .map((x) => Operation.fromMap(Map<String, dynamic>.from(x)))
          .toList();

      await SyncService.batchSetVentes(ventesLegacy.map((v) => v.toMap()).toList());
      await SyncService.batchSetOps(opsLegacy.map((o) => o.toMap()).toList());

      _applyMeta({
        "banques": meta["banques"],
        "active": meta["active"],
        "produits": meta["produits"],
      });
      await SyncService.pushMeta(_metaMap()); // réécrit le doc sans ventes/ops -> le fait rétrécir

      ventes = ventesLegacy;
      ops = opsLegacy;
      box.put("ventes", ventes.map((x) => x.toMap()).toList());
      box.put("ops", ops.map((x) => x.toMap()).toList());
      _opsVersion++;
      _syncedVentes = {for (final v in ventes) v.id: v.toMap()};
      _syncedOps = {for (final o in ops) o.id: o.toMap()};

      debugPrint("Migration terminée : ${ventes.length} ventes, ${ops.length} opérations.");
    } else {
      _applyMeta(meta);
      // Pas de re-téléchargement complet ici : seules les ventes/opérations
      // récentes sont vérifiées (voir _syncRecent), pour éviter de
      // retraiter des milliers d'éléments à chaque ouverture de l'appli.
      // Pour un rattrapage complet (ex: après un gros import), utilise le
      // bouton dans Réglages (voir [resynchroniserTout]).
      await _syncRecent();
    }

    notifyListeners();
    startRealtimeSync();
  }

  /// Vérifie uniquement les ventes/opérations des derniers jours (ex: une
  /// vente ajoutée automatiquement par la synchro PayPal ce matin). Rapide
  /// (quelques documents au lieu de plusieurs milliers).
  Future<void> _syncRecent({int jours = 3}) async {
    final depuis = DateTime.now().subtract(Duration(days: jours));

    final ventesRecentes = await SyncService.pullVentesDepuis(depuis);
    final opsRecentes = await SyncService.pullOpsDepuis(depuis);

    _fusionnerVentes(ventesRecentes);
    _fusionnerOps(opsRecentes);
  }

  /// Rattrapage complet : relit TOUTES les ventes/opérations du cloud et
  /// les compare à ce qu'il y a en local. Coûteux avec beaucoup de ventes
  /// (plusieurs secondes) — à ne déclencher qu'à la demande (bouton dans
  /// Réglages), pas automatiquement à chaque ouverture de l'appli.
  Future<ResyncResult> resynchroniserTout() async {
    final ventesCloud = await SyncService.pullAllVentes();
    final opsCloud = await SyncService.pullAllOps();

    final nvVentes = _fusionnerVentes(ventesCloud);
    final nvOps = _fusionnerOps(opsCloud);

    return ResyncResult(ventesMaj: nvVentes, opsMaj: nvOps);
  }

  /// Fusionne une liste de ventes reçues du cloud dans l'état local ; ne
  /// touche que celles qui ont réellement changé. Retourne le nombre de
  /// ventes effectivement mises à jour/ajoutées.
  int _fusionnerVentes(List<Map<String, dynamic>> ventesCloud) {
    if (ventesCloud.isEmpty) return 0;
    final parId = {for (final v in ventes) v.id: v};
    int compte = 0;
    for (final data in ventesCloud) {
      final id = data["id"] as String?;
      if (id == null) continue;
      if (_mapsEgales(_syncedVentes[id] ?? const {}, data)) continue;
      parId[id] = Vente.fromMap(data);
      _syncedVentes[id] = data;
      compte++;
    }
    if (compte > 0) {
      ventes = parId.values.toList();
      box.put("ventes", ventes.map((x) => x.toMap()).toList());
      notifyListeners();
    }
    return compte;
  }

  int _fusionnerOps(List<Map<String, dynamic>> opsCloud) {
    if (opsCloud.isEmpty) return 0;
    final parId = {for (final o in ops) o.id: o};
    int compte = 0;
    for (final data in opsCloud) {
      final id = data["id"] as String?;
      if (id == null) continue;
      if (_mapsEgales(_syncedOps[id] ?? const {}, data)) continue;
      parId[id] = Operation.fromMap(data);
      _syncedOps[id] = data;
      compte++;
    }
    if (compte > 0) {
      ops = parId.values.toList();
      box.put("ops", ops.map((x) => x.toMap()).toList());
      _opsVersion++;
      notifyListeners();
    }
    return compte;
  }

  /// Écoute temps réel : uniquement la méta (comptes/produits/actif), qui
  /// est petite et change rarement. Les ventes/opérations ne sont PAS
  /// écoutées en continu — Firestore renverrait tout l'historique à chaque
  /// nouvelle connexion, ce qui rendait l'appli inutilisable avec plusieurs
  /// milliers de ventes. À la place : [_syncRecent] au démarrage (ventes
  /// des derniers jours seulement) et [resynchroniserTout] à la demande
  /// (bouton dans Réglages).
  void startRealtimeSync() {
    _metaSub?.cancel();
    _metaSub = SyncService.listenToMeta((data) {
      // Si on vient d'écrire localement, on ignore cet écho pour ne pas
      // s'auto-écraser (même garde-fou que dans l'app Fidélité).
      if (_lastLocalWrite != null) {
        final elapsed = DateTime.now().difference(_lastLocalWrite!).inMilliseconds;
        if (elapsed < _syncProtectionMs) return;
      }
      _applyMeta(data);
    });
  }

  void stopRealtimeSync() {
    _metaSub?.cancel();
    _metaSub = null;
  }

  /// Sauvegarde locale (Hive, inchangé) + synchro cloud. Par défaut, pour
  /// les ventes et opérations, on ne pousse QUE ce qui a changé depuis le
  /// dernier appel (ajouts/modifs/suppressions), peu importe où la
  /// modification a été faite dans le code (ex: `s.ops.add(...)` puis
  /// `s.save()` directement depuis un écran).
  ///
  /// [skipCloudDiff] : à utiliser quand l'appelant a déjà poussé lui-même
  /// l'élément précis qui a changé (voir [togglePointage], [enregistrerVente]
  /// etc.) — ça évite de reparcourir des milliers de ventes/opérations pour
  /// une seule case cochée, ce qui rendait l'appli très lente à chaque clic.
  ///
  /// [ventesChanged]/[opsChanged] : par défaut à `true` (comportement sûr,
  /// réécrit tout au cas où) ; les méthodes qui savent déjà que "ventes" ou
  /// "ops" n'a pas bougé peuvent passer `false` pour éviter de resérialiser
  /// des milliers d'éléments sur le disque pour rien.
  void save({
    bool skipCloudDiff = false,
    bool ventesChanged = true,
    bool opsChanged = true,
  }) {
    box.put("banques", banques);
    box.put("active", active);
    box.put("produits", produits.map((x) => x.toMap()).toList());
    box.put("paniersEnAttente", paniersEnAttente.map((x) => x.toMap()).toList());
    if (opsChanged) {
      box.put("ops", ops.map((x) => x.toMap()).toList());
      _opsVersion++;
    }
    if (ventesChanged) box.put("ventes", ventes.map((x) => x.toMap()).toList());
    _lastLocalWrite = DateTime.now();

    SyncService.pushMeta(_metaMap());
    if (!skipCloudDiff) {
      _syncVentesEtOpsModifiees();
    }

    notifyListeners();
  }

  /// Pousse une seule opération vers le cloud et met à jour le "déjà
  /// synchronisé" correspondant — à utiliser avec `save(skipCloudDiff: true)`
  /// pour les actions fréquentes (pointage, etc.) plutôt que de tout
  /// rediffuser.
  void _syncUneOp(Operation o) {
    final m = o.toMap();
    _syncedOps[o.id] = m;
    SyncService.setOperation(m);
  }

  void _syncUneVente(Vente v) {
    final m = v.toMap();
    _syncedVentes[v.id] = m;
    SyncService.setVente(m);
  }

  void _desyncOp(String id) {
    _syncedOps.remove(id);
    SyncService.deleteOperation(id);
  }

  void _desyncVente(String id) {
    _syncedVentes.remove(id);
    SyncService.deleteVente(id);
  }

  bool _mapsEgales(Map a, Map b) => jsonEncode(a) == jsonEncode(b);

  void _syncVentesEtOpsModifiees() {
    final currentVentes = {for (final v in ventes) v.id: v.toMap()};
    final ventesASupprimer =
        _syncedVentes.keys.where((id) => !currentVentes.containsKey(id)).toList();
    final ventesAEnvoyer = currentVentes.entries
        .where((e) => !_mapsEgales(_syncedVentes[e.key] ?? const {}, e.value))
        .map((e) => e.value)
        .toList();

    if (ventesAEnvoyer.length == 1) {
      SyncService.setVente(ventesAEnvoyer.first);
    } else if (ventesAEnvoyer.length > 1) {
      SyncService.batchSetVentes(ventesAEnvoyer);
    }
    for (final id in ventesASupprimer) {
      SyncService.deleteVente(id);
    }
    _syncedVentes = currentVentes;

    final currentOps = {for (final o in ops) o.id: o.toMap()};
    final opsASupprimer =
        _syncedOps.keys.where((id) => !currentOps.containsKey(id)).toList();
    final opsAEnvoyer = currentOps.entries
        .where((e) => !_mapsEgales(_syncedOps[e.key] ?? const {}, e.value))
        .map((e) => e.value)
        .toList();

    if (opsAEnvoyer.length == 1) {
      SyncService.setOperation(opsAEnvoyer.first);
    } else if (opsAEnvoyer.length > 1) {
      SyncService.batchSetOps(opsAEnvoyer);
    }
    for (final id in opsASupprimer) {
      SyncService.deleteOperation(id);
    }
    _syncedOps = currentOps;
  }

  // ===================== OPERATIONS =====================

  void removeById(String id) {
    ops.removeWhere((o) => o.id == id);
    _desyncOp(id);
    save(skipCloudDiff: true, ventesChanged: false);
  }

  /// Ajoute une opération saisie manuellement (recette/dépense) — ne
  /// synchronise que celle-ci, pas tout l'historique.
  void addOperation(Operation o) {
    ops.add(o);
    _syncUneOp(o);
    save(skipCloudDiff: true, ventesChanged: false);
  }

  void transfer({
    required String from,
    required String to,
    required double montant,
    required String desc,
    required DateTime date,
  }) {
    final baseId = DateTime.now().microsecondsSinceEpoch.toString();
    final sortie = Operation(
      id: '${baseId}_from',
      desc: desc,
      montant: montant,
      depense: true,
      date: date,
      banque: from,
      transfert: true,
      banqueCible: to,
    );
    final entree = Operation(
      id: '${baseId}_to',
      desc: desc,
      montant: montant,
      depense: false,
      date: date,
      banque: to,
      transfert: true,
      banqueCible: from,
    );

    ops.addAll([sortie, entree]);
    _syncUneOp(sortie);
    _syncUneOp(entree);
    save(skipCloudDiff: true, ventesChanged: false);
  }

  /// Une opération déjà présente dans [ops] a été modifiée en place (ex:
  /// édition manuelle) — ne synchronise que celle-ci.
  void syncOperationModifiee(Operation o) {
    _syncUneOp(o);
    save(skipCloudDiff: true, ventesChanged: false);
  }

  // Cache de opsActives() : le calendrier appelle cette méthode pour
  // CHAQUE jour affiché (~35 fois par rendu). Sans cache, ça refiltre les
  // 3461+ opérations à chaque fois, ce qui rend le calendrier très lent une
  // fois qu'il y a beaucoup de ventes PayPal importées. Invalidé dès que
  // "ops" ou le compte actif change (voir _opsVersion, incrémenté dans save()).
  int _opsVersion = 0;
  List<Operation>? _opsActivesCache;
  int? _opsActivesCacheVersion;
  String? _opsActivesCacheBanque;

  List<Operation> opsActives() {
    if (active == null) return [];
    if (_opsActivesCache != null &&
        _opsActivesCacheVersion == _opsVersion &&
        _opsActivesCacheBanque == active) {
      return _opsActivesCache!;
    }
    final list = ops.where((o) => o.banque == active).toList();
    _opsActivesCache = list;
    _opsActivesCacheVersion = _opsVersion;
    _opsActivesCacheBanque = active;
    return list;
  }

  // ===== Cache "solde" : évite de reparcourir toutes les opérations pour
  // chaque jour du calendrier (avant : O(jours x opérations), soit des
  // centaines de milliers d'itérations rien que pour afficher un mois avec
  // plusieurs milliers de ventes PayPal). =====
  //
  // Les opérations "ponctuelles" (l'immense majorité — une par vente
  // PayPal) sont triées par date une fois, avec une somme cumulée
  // (préfixe) : trouver le solde à une date donnée devient une recherche
  // binaire (quasi instantané) plutôt qu'un parcours complet. Les
  // opérations récurrentes (factures mensuelles, etc.) restent peu
  // nombreuses : leur calcul au cas par cas reste inchangé.
  List<Operation>? _ponctuelsTries;
  List<Operation>? _recurrents;
  List<double>? _prefixeTous;
  List<double>? _prefixePointes;
  Set<String>? _joursAvecPonctuel;
  int? _soldeCacheVersion;
  String? _soldeCacheBanque;

  String _cleJour(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  void _rafraichirCacheSoldeSiBesoin() {
    if (_soldeCacheVersion == _opsVersion && _soldeCacheBanque == active) return;

    final actives = opsActives();
    final ponctuels = actives.where((o) => o.f == Frequence.ponctuel).toList()
      ..sort((a, b) => a.dateJour.compareTo(b.dateJour));
    final recurrents = actives.where((o) => o.f != Frequence.ponctuel).toList();

    final prefixeTous = <double>[];
    final prefixePointes = <double>[];
    final jours = <String>{};
    double cumulTous = 0;
    double cumulPointes = 0;

    for (final o in ponctuels) {
      final delta = o.depense ? -o.montant : o.montant;
      cumulTous += delta;
      if (o.isPointed(o.dateJour)) cumulPointes += delta;
      prefixeTous.add(cumulTous);
      prefixePointes.add(cumulPointes);
      jours.add(_cleJour(o.dateJour));
    }

    _ponctuelsTries = ponctuels;
    _recurrents = recurrents;
    _prefixeTous = prefixeTous;
    _prefixePointes = prefixePointes;
    _joursAvecPonctuel = jours;
    _soldeCacheVersion = _opsVersion;
    _soldeCacheBanque = active;
  }

  /// Dernier index (recherche binaire) dont la date ne dépasse pas [cible].
  int _dernierIndexAvant(List<Operation> tries, DateTime cible) {
    int lo = 0, hi = tries.length - 1, res = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (!tries[mid].dateJour.isAfter(cible)) {
        res = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return res;
  }

  /// Vrai si au moins une opération a lieu ce jour-là — utilisé par le
  /// calendrier pour savoir s'il faut afficher un indicateur, en O(1) au
  /// lieu de reparcourir toutes les opérations pour chaque jour affiché.
  bool hasOperationOn(DateTime day) {
    if (active == null) return false;
    final jour = DateTime(day.year, day.month, day.day);
    _rafraichirCacheSoldeSiBesoin();

    if (_joursAvecPonctuel!.contains(_cleJour(jour))) return true;
    for (final o in _recurrents!) {
      if (o.occursOn(jour)) return true;
    }
    return false;
  }

  double getSoldeAu(DateTime cible, bool seulementPointe) {
    if (active == null) return 0;
    final jour = DateTime(cible.year, cible.month, cible.day);
    _rafraichirCacheSoldeSiBesoin();

    double total = 0;

    final idx = _dernierIndexAvant(_ponctuelsTries!, jour);
    if (idx >= 0) {
      total += seulementPointe ? _prefixePointes![idx] : _prefixeTous![idx];
    }

    // Opérations récurrentes : peu nombreuses, calcul inchangé au cas par cas.
    for (final o in _recurrents!) {
      switch (o.f) {
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
    _syncUneOp(op);
    save(skipCloudDiff: true, ventesChanged: false);
  }

  /// Pointer le passé : re-pointe tout (vide les dépointages). Peut
  /// concerner plusieurs milliers d'opérations (toutes celles importées de
  /// PayPal comprises) : on envoie ça par lot plutôt qu'un appel réseau par
  /// opération.
  void autoPointAllPast() {
    final touchees = <Operation>[];
    for (final o in opsActives()) {
      if (o.pointages.isNotEmpty) {
        o.pointages.clear();
        touchees.add(o);
      }
    }
    for (final o in touchees) {
      _syncedOps[o.id] = o.toMap();
    }
    if (touchees.isNotEmpty) {
      SyncService.batchSetOps(touchees.map((o) => o.toMap()).toList());
    }
    save(skipCloudDiff: true, ventesChanged: false);
  }

  void deleteOccurrence(Operation op, DateTime day) {
    final key =
        DateTime(day.year, day.month, day.day).toIso8601String().substring(0, 10);
    op.exclusions.add(key);
    _syncUneOp(op);
    save(skipCloudDiff: true, ventesChanged: false);
  }

  void deleteFrom(Operation op, DateTime day) {
    final veille =
        DateTime(day.year, day.month, day.day).subtract(const Duration(days: 1));
    op.finRecurrence = veille;
    _syncUneOp(op);
    save(skipCloudDiff: true, ventesChanged: false);
  }

  // ===================== PRODUITS =====================

  void addProduit(Produit p) {
    produits.add(p);
    save(skipCloudDiff: true, ventesChanged: false, opsChanged: false);
  }

  void updateProduit(Produit p) {
    final i = produits.indexWhere((x) => x.id == p.id);
    if (i != -1) produits[i] = p;
    save(skipCloudDiff: true, ventesChanged: false, opsChanged: false);
  }

  void removeProduit(String id) {
    produits.removeWhere((p) => p.id == id);
    save(skipCloudDiff: true, ventesChanged: false, opsChanged: false);
  }

  // ===================== PANIERS EN ATTENTE =====================

  void sauvegarderPanierEnAttente(List<VenteItem> items) {
    if (items.isEmpty) return;
    paniersEnAttente.insert(
      0,
      PanierEnAttente(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: DateTime.now(),
        items: items,
      ),
    );
    save(skipCloudDiff: true, ventesChanged: false, opsChanged: false);
  }

  void supprimerPanierEnAttente(String id) {
    paniersEnAttente.removeWhere((p) => p.id == id);
    save(skipCloudDiff: true, ventesChanged: false, opsChanged: false);
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
    List<Reglement>? reglements,
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
      reglements: reglements,
    );

    ops.add(operation);
    ventes.add(vente);
    _syncUneOp(operation);
    _syncUneVente(vente);
    save(skipCloudDiff: true);

    return vente;
  }

  void deleteVente(Vente v) {
    ventes.removeWhere((x) => x.id == v.id);
    _desyncVente(v.id);
    if (v.operationId != null) {
      ops.removeWhere((o) => o.id == v.operationId);
      _desyncOp(v.operationId!);
    }
    save(skipCloudDiff: true);
  }

  /// Met à jour une vente existante (date, mode, articles) et synchronise
  /// l'opération de recette liée dans le calendrier.
  void updateVente({
    required Vente vente,
    required DateTime date,
    required ModePaiement mode,
    required List<VenteItem> items,
    List<Reglement>? reglements,
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
    vente.reglements = reglements ?? [Reglement(mode: mode, montant: total)];

    if (vente.operationId != null) {
      final idx = ops.indexWhere((o) => o.id == vente.operationId);
      if (idx != -1) {
        ops[idx].desc = vente.label;
        ops[idx].montant = total;
        ops[idx].date = jour;
        _syncUneOp(ops[idx]);
      }
    }

    _syncUneVente(vente);
    save(skipCloudDiff: true);
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
    for (final v in nouvellesVentes) {
      _syncedVentes[v.id] = v.toMap();
    }
    for (final o in nouvellesOps) {
      _syncedOps[o.id] = o.toMap();
    }
    if (nouvellesVentes.isNotEmpty) {
      SyncService.batchSetVentes(nouvellesVentes.map((v) => v.toMap()).toList());
      SyncService.batchSetOps(nouvellesOps.map((o) => o.toMap()).toList());
      save(skipCloudDiff: true);
    }

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

class ResyncResult {
  final int ventesMaj;
  final int opsMaj;
  ResyncResult({required this.ventesMaj, required this.opsMaj});
}