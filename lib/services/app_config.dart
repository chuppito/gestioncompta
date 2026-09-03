import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppConfig extends ChangeNotifier {
  static final AppConfig I = AppConfig._();
  AppConfig._() {
    _load();
  }

  final box = Hive.box("db");

  String _currency = "€";
  String get currency => _currency;

  void _load() {
    _currency = box.get("currency") ?? "€";
  }

  void updateCurrency(String cur) {
    _currency = cur;
    box.put("currency", cur);
    notifyListeners();
  }
}
