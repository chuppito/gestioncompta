import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/carte_pizza.dart';

/// Récupère la carte des pizzas depuis le même Google Sheet publié que
/// l'app La Casita, pour que "Gestion Compta" propose toujours exactement
/// les mêmes pizzas, aux mêmes prix, sans ressaisie manuelle.
///
/// Les boissons et suppléments restent gérés à la main via l'écran
/// "Mes produits", puisqu'ils ne sont pas présents dans ce tableur.
class CarteService {
  CarteService._();
  static final CarteService instance = CarteService._();

  // Même lien "publié sur le web" (format TSV) que dans l'app La Casita.
  static final Uri _sheetUrl = Uri.parse(
    'https://docs.google.com/spreadsheets/d/e/2PACX-1vQGNPINjsEFyWSYpCCjK9wneSvhhSgA6Ww1krcTzUUT7Oyz6pXK5lvEkMBMVfmxf2ymLu5VNBDlQa4g/pub?gid=0&single=true&output=tsv',
  );

  static const String _cacheKey = 'carte_pizzas_cache_v1';

  /// Récupère la carte : tente le réseau, retombe sur le cache local en cas
  /// d'échec (hors-ligne), et met à jour le cache à chaque succès.
  Future<List<CartePizza>> fetchPizzas() async {
    try {
      final response = await http.get(_sheetUrl);
      if (response.statusCode == 200) {
        final pizzas = _parseTsv(utf8.decode(response.bodyBytes));
        if (pizzas.isNotEmpty) {
          await _saveCache(pizzas);
          return pizzas;
        }
      }
    } catch (_) {
      // pas de réseau / sheet indisponible -> on retombe sur le cache
    }
    return _loadCache();
  }

  List<CartePizza> _parseTsv(String tsv) {
    final lines = tsv.split(RegExp(r'\r?\n'));
    final pizzas = <CartePizza>[];

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final columns = line.split('\t');
      if (columns.length < 4) continue;

      final nom = columns[0].trim().replaceAll('"', '');
      if (nom.isEmpty) continue;

      final categorie = columns[1].trim().replaceAll('"', '');

      final rawIngredients = columns[2].trim().replaceAll('"', '');
      final ingredients = rawIngredients
          .split(',')
          .map((ing) => ing.trim())
          .where((ing) => ing.isNotEmpty)
          .toList();

      String rawPrice = columns[3].trim().replaceAll('"', '');
      rawPrice = rawPrice
          .replaceAll('€', '')
          .replaceAll(',', '.')
          .replaceAll(RegExp(r'\s+'), '')
          .trim();
      final prix = double.tryParse(rawPrice) ?? 0.0;

      pizzas.add(CartePizza(
        id: 'carte_$i',
        nom: nom,
        categorie: categorie.isEmpty ? 'Pizza' : categorie,
        ingredients: ingredients,
        prix: prix,
      ));
    }

    return pizzas;
  }

  Future<void> _saveCache(List<CartePizza> pizzas) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(pizzas.map((p) => p.toJson()).toList());
      await prefs.setString(_cacheKey, jsonStr);
    } catch (_) {
      // le cache est un confort, pas une nécessité
    }
  }

  Future<List<CartePizza>> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cacheKey);
      if (jsonStr == null) return [];
      final List data = jsonDecode(jsonStr);
      return data
          .map((e) => CartePizza.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
