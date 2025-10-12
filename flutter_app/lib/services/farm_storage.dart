// lib/farm_storage.dart
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:latlong2/latlong.dart';

class FarmStorage {
  static const String fileName = 'farms.json';
  static const String polygonFileName = 'polygon.json';

  // -------------------------------
  // Internal helper: get file path
  // -------------------------------
  static Future<File> _localFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  static Future<File> _polygonFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$polygonFileName');
  }

  // -------------------------------
  // FIELD MANAGEMENT
  // -------------------------------
  /// Load all saved fields (returns list)
  static Future<List<Map<String, dynamic>>> loadAllFields() async {
    try {
      final file = await _localFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final List data = jsonDecode(content);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('loadAllFields error: $e');
      return [];
    }
  }

  /// Save a new field (append)
  static Future<void> saveField(Map<String, dynamic> field) async {
    final file = await _localFile();
    final list = await loadAllFields();
    list.add(field);
    await file.writeAsString(jsonEncode(list));
  }

  /// Update an existing field by id
  static Future<void> updateField(String id, Map<String, dynamic> field) async {
    final file = await _localFile();
    final list = await loadAllFields();
    final idx = list.indexWhere((e) => e['id'] == id);
    if (idx >= 0) {
      list[idx] = field;
      await file.writeAsString(jsonEncode(list));
    }
  }

  /// Delete a field by id
  static Future<void> deleteField(String id) async {
    final file = await _localFile();
    final list = await loadAllFields();
    list.removeWhere((e) => e['id'] == id);
    await file.writeAsString(jsonEncode(list));
  }

  static Future<void> clearAll() async {
    final file = await _localFile();
    if (await file.exists()) await file.delete();
  }

  // -------------------------------
  // POLYGON MANAGEMENT (NEW)
  // -------------------------------
  /// ✅ Save polygon coordinates only (used for “My Farm”)
  static Future<void> savePolygon(List<LatLng> points) async {
    final file = await _polygonFile();
    final data = points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList();
    await file.writeAsString(jsonEncode(data));
  }

  /// ✅ Load saved polygon (if exists)
  static Future<List<LatLng>> loadPolygon() async {
    try {
      final file = await _polygonFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final List data = jsonDecode(content);
      return data.map((e) => LatLng(e['lat'], e['lng'])).toList();
    } catch (e) {
      print('loadPolygon error: $e');
      return [];
    }
  }

  /// ✅ Clear polygon file
  static Future<void> clearPolygon() async {
    final file = await _polygonFile();
    if (await file.exists()) await file.delete();
  }
}
