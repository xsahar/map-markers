import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audit_pin.dart';

class AuditManager {
  static final AuditManager _instance = AuditManager._internal();
  factory AuditManager() => _instance;
  AuditManager._internal();

  final List<AuditPin> _pins = [];
  static const String _storageKey = 'saved_audit_pins';

  List<AuditPin> get pins => List.unmodifiable(_pins);

  // Load saved pins from device storage
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final String? pinsJson = prefs.getString(_storageKey);
    if (pinsJson != null) {
      final List<dynamic> decoded = jsonDecode(pinsJson);
      _pins.clear();
      _pins.addAll(decoded.map((item) => AuditPin.fromJson(item)).toList());
    }
  }

  // Save current list to device storage
  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_pins.map((p) => p.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> addPin(LatLng location, String title, String snippet) async {
    final newPin = AuditPin(
      id: 'pin_${DateTime.now().millisecondsSinceEpoch}',
      location: location,
      title: title,
      snippet: snippet,
      timestamp: DateTime.now(),
    );
    _pins.add(newPin);
    await _saveToPrefs();
  }

  Future<void> removePin(String id) async {
    _pins.removeWhere((pin) => pin.id == id);
    await _saveToPrefs();
  }

  Future<void> clearAll() async {
    _pins.clear();
    await _saveToPrefs();
  }
}