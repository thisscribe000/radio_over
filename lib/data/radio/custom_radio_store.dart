import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/station.dart';

/// Store for user-defined custom radio stream URLs.
abstract class CustomRadioStore {
  Future<List<RadioStation>> load();
  Future<void> save(List<RadioStation> stations);
  Future<void> addStation(RadioStation station);
  Future<void> removeStation(String id);
}

class InMemoryCustomRadioStore implements CustomRadioStore {
  final List<RadioStation> _stations = [];

  @override
  Future<List<RadioStation>> load() async => List<RadioStation>.of(_stations);

  @override
  Future<void> save(List<RadioStation> stations) async {
    _stations.clear();
    _stations.addAll(stations);
  }

  @override
  Future<void> addStation(RadioStation station) async {
    _stations.removeWhere((s) => s.stationId == station.stationId);
    _stations.insert(0, station);
  }

  @override
  Future<void> removeStation(String id) async {
    _stations.removeWhere((s) => s.stationId == id);
  }
}

class SharedPreferencesCustomRadioStore implements CustomRadioStore {
  static const String _key = 'custom-stations-v1';

  @override
  Future<List<RadioStation>> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map((m) => RadioStation(
                id: m['id'] as String?,
                name: m['name'] as String? ?? 'Custom Radio',
                category: m['category'] as String? ?? 'Custom',
                program: m['program'] as String? ?? 'LIVE STREAM',
                country: m['country'] as String?,
                city: m['city'] as String?,
                streamUrl: m['streamUrl'] as String?,
                isOnline: true,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> save(List<RadioStation> stations) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> data = stations
        .map((s) => {
              'id': s.id,
              'name': s.name,
              'category': s.category,
              'program': s.program,
              'country': s.country,
              'city': s.city,
              'streamUrl': s.streamUrl,
            })
        .toList();
    await prefs.setString(_key, jsonEncode(data));
  }

  @override
  Future<void> addStation(RadioStation station) async {
    final List<RadioStation> current = await load();
    current.removeWhere((s) => s.stationId == station.stationId);
    current.insert(0, station);
    await save(current);
  }

  @override
  Future<void> removeStation(String id) async {
    final List<RadioStation> current = await load();
    current.removeWhere((s) => s.stationId == id);
    await save(current);
  }
}
