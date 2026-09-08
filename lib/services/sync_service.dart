import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

/// Sauvegarde/restaure l'état de [Store] dans Firestore, sous le compte
/// connecté (même projet Firebase "fidelite-pizzas" que l'app Fidélité).
///
/// Structure (depuis la migration "1 doc par vente") :
///   users/{uid}/gestioncompta_data/store            <- petit doc : banques, active, produits
///   users/{uid}/gestioncompta_data/store/ventes/{id} <- 1 document par vente
///   users/{uid}/gestioncompta_data/store/ops/{id}    <- 1 document par opération
///
/// Avant, tout (y compris ventes et opérations) était dans un seul document
/// "store" — ça a fini par dépasser la limite de 1 Mo par document Firestore
/// dès qu'il y a eu beaucoup de ventes (import PayPal). Chaque vente/opération
/// est maintenant son propre petit document : plus aucune limite de ce type,
/// même avec des dizaines de milliers de ventes.
class SyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> get _metaDoc {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) throw Exception('Utilisateur non connecté');
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('gestioncompta_data')
        .doc('store');
  }

  static CollectionReference<Map<String, dynamic>> get _ventesCol =>
      _metaDoc.collection('ventes');

  static CollectionReference<Map<String, dynamic>> get _opsCol =>
      _metaDoc.collection('ops');

  // ==================== MÉTA (banques / active / produits) ====================
  // Petit document, change rarement, même logique qu'avant.

  static Future<void> pushMeta(Map<String, dynamic> data) async {
    if (!AuthService.isLoggedIn) return;
    try {
      await _metaDoc.set(data);
    } catch (e) {
      debugPrint('Erreur synchro Firestore (push meta) : $e');
    }
  }

  static Future<Map<String, dynamic>?> pullMeta() async {
    if (!AuthService.isLoggedIn) return null;
    try {
      final snap = await _metaDoc.get();
      return snap.data();
    } catch (e) {
      debugPrint('Erreur synchro Firestore (pull meta) : $e');
      return null;
    }
  }

  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      listenToMeta(void Function(Map<String, dynamic> data) onData) {
    if (!AuthService.isLoggedIn) return null;
    return _metaDoc.snapshots().listen(
      (snap) {
        final data = snap.data();
        if (data != null) onData(data);
      },
      onError: (e) => debugPrint('Erreur écoute Firestore (meta) : $e'),
    );
  }

  // ==================== VENTES ====================

  static Future<void> setVente(Map<String, dynamic> data) async {
    if (!AuthService.isLoggedIn) return;
    try {
      await _ventesCol.doc(data['id'] as String).set(data);
    } catch (e) {
      debugPrint('Erreur synchro Firestore (set vente) : $e');
    }
  }

  static Future<void> deleteVente(String id) async {
    if (!AuthService.isLoggedIn) return;
    try {
      await _ventesCol.doc(id).delete();
    } catch (e) {
      debugPrint('Erreur synchro Firestore (delete vente) : $e');
    }
  }

  static Future<List<Map<String, dynamic>>> pullAllVentes() async {
    if (!AuthService.isLoggedIn) return [];
    try {
      final snap = await _ventesCol.get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      debugPrint('Erreur synchro Firestore (pull ventes) : $e');
      return [];
    }
  }

  /// Ne récupère que les ventes datées à partir de [depuis] — beaucoup plus
  /// rapide qu'un pull complet, utilisé au démarrage normal de l'appli pour
  /// rattraper uniquement les ventes récentes (ex: importées automatiquement
  /// par la synchro PayPal dans les dernières heures/jours).
  static Future<List<Map<String, dynamic>>> pullVentesDepuis(DateTime depuis) async {
    if (!AuthService.isLoggedIn) return [];
    try {
      final snap = await _ventesCol
          .where('dt', isGreaterThanOrEqualTo: depuis.toIso8601String())
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      debugPrint('Erreur synchro Firestore (pull ventes récentes) : $e');
      return [];
    }
  }

  /// Écoute les ajouts/modifications/suppressions de ventes en temps réel
  /// (ex : une vente enregistrée depuis un autre téléphone, ou synchronisée
  /// par l'automatisation PayPal). Les changements d'un même instantané sont
  /// regroupés en une seule liste : l'appelant doit les traiter puis
  /// sauvegarder UNE SEULE FOIS, plutôt qu'à chaque document (avec des
  /// milliers de ventes, faire une sauvegarde + un rafraîchissement d'écran
  /// par document rend l'appli inutilisable au premier chargement).
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      listenToVentes(
    void Function(List<DocumentChange<Map<String, dynamic>>> changes) onChanges,
  ) {
    if (!AuthService.isLoggedIn) return null;
    return _ventesCol.snapshots().listen(
      (snap) {
        final changes = snap.docChanges
            .where((c) => !c.doc.metadata.hasPendingWrites)
            .toList();
        if (changes.isNotEmpty) onChanges(changes);
      },
      onError: (e) => debugPrint('Erreur écoute Firestore (ventes) : $e'),
    );
  }

  // ==================== OPÉRATIONS ====================

  static Future<void> setOperation(Map<String, dynamic> data) async {
    if (!AuthService.isLoggedIn) return;
    try {
      await _opsCol.doc(data['id'] as String).set(data);
    } catch (e) {
      debugPrint('Erreur synchro Firestore (set op) : $e');
    }
  }

  static Future<void> deleteOperation(String id) async {
    if (!AuthService.isLoggedIn) return;
    try {
      await _opsCol.doc(id).delete();
    } catch (e) {
      debugPrint('Erreur synchro Firestore (delete op) : $e');
    }
  }

  static Future<List<Map<String, dynamic>>> pullAllOps() async {
    if (!AuthService.isLoggedIn) return [];
    try {
      final snap = await _opsCol.get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      debugPrint('Erreur synchro Firestore (pull ops) : $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> pullOpsDepuis(DateTime depuis) async {
    if (!AuthService.isLoggedIn) return [];
    try {
      final snap = await _opsCol
          .where('dt', isGreaterThanOrEqualTo: depuis.toIso8601String())
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      debugPrint('Erreur synchro Firestore (pull ops récentes) : $e');
      return [];
    }
  }

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      listenToOps(
    void Function(List<DocumentChange<Map<String, dynamic>>> changes) onChanges,
  ) {
    if (!AuthService.isLoggedIn) return null;
    return _opsCol.snapshots().listen(
      (snap) {
        final changes = snap.docChanges
            .where((c) => !c.doc.metadata.hasPendingWrites)
            .toList();
        if (changes.isNotEmpty) onChanges(changes);
      },
      onError: (e) => debugPrint('Erreur écoute Firestore (ops) : $e'),
    );
  }

  // ==================== ÉCRITURE PAR LOTS (migration / import) ====================
  // Firestore limite un batch à 500 écritures : on découpe automatiquement.

  static Future<void> batchSetVentes(List<Map<String, dynamic>> ventes) =>
      _batchSet(_ventesCol, ventes);

  static Future<void> batchSetOps(List<Map<String, dynamic>> ops) =>
      _batchSet(_opsCol, ops);

  static Future<void> _batchSet(
    CollectionReference<Map<String, dynamic>> col,
    List<Map<String, dynamic>> docs,
  ) async {
    if (!AuthService.isLoggedIn || docs.isEmpty) return;
    try {
      for (var i = 0; i < docs.length; i += 450) {
        final batch = _firestore.batch();
        final chunk = docs.sublist(i, i + 450 > docs.length ? docs.length : i + 450);
        for (final d in chunk) {
          batch.set(col.doc(d['id'] as String), d);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Erreur synchro Firestore (batch) : $e');
    }
  }
}
