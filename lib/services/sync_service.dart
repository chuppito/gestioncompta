import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

/// Sauvegarde/restaure l'état de [Store] dans Firestore, sous le compte
/// connecté (même projet Firebase "fidelite-pizzas" que l'app Fidélité).
///
/// Les données sont rangées sous `users/{uid}/gestioncompta_data/store`
/// pour ne jamais entrer en collision avec les autres champs déjà utilisés
/// sous `users/{uid}` par les autres apps (numéro de téléphone du
/// restaurant, statut ouvert/fermé, etc.).
///
/// Se connecter avec le même compte depuis un autre téléphone permet donc
/// de récupérer exactement les mêmes comptes, produits et ventes.
class SyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> get _doc {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      throw Exception('Utilisateur non connecté');
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('gestioncompta_data')
        .doc('store');
  }

  /// Pousse l'état local complet vers le cloud (appelé après chaque
  /// sauvegarde locale via [Store.save]). Best-effort : une erreur réseau
  /// ne doit jamais bloquer l'usage hors-ligne de l'app.
  static Future<void> pushToCloud(Map<String, dynamic> data) async {
    if (!AuthService.isLoggedIn) return;
    try {
      await _doc.set(data);
    } catch (e) {
      debugPrint('Erreur synchro Firestore (push) : $e');
    }
  }

  /// Récupère l'état sauvegardé dans le cloud, ou `null` si absent /
  /// hors-ligne / pas encore connecté.
  static Future<Map<String, dynamic>?> pullFromCloud() async {
    if (!AuthService.isLoggedIn) return null;
    try {
      final snap = await _doc.get();
      return snap.data();
    } catch (e) {
      debugPrint('Erreur synchro Firestore (pull) : $e');
      return null;
    }
  }

  /// Écoute les changements distants en temps réel (ex : une vente
  /// enregistrée depuis un autre téléphone connecté au même compte).
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      listenToCloud(void Function(Map<String, dynamic> data) onData) {
    if (!AuthService.isLoggedIn) return null;
    return _doc.snapshots().listen(
      (snap) {
        final data = snap.data();
        if (data != null) onData(data);
      },
      onError: (e) => debugPrint('Erreur écoute Firestore : $e'),
    );
  }
}
