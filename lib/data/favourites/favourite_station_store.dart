import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/station.dart';

/// Persists the listener's favourite stations across restarts.
///
/// Stores a stable station identifier plus a small cached metadata snapshot —
/// enough to render the Library's favourites without the directory (and
/// without duplicating live catalogue objects). A station that later goes
/// offline is never auto-removed; it simply renders with its snapshot and an
/// unavailable state.
abstract class FavouriteStationStore {
  /// Restores saved favourites: station id → cached snapshot.
  Future<Map<String, RadioStation>> load();

  /// Replaces the stored set with [favourites].
  Future<void> save(Map<String, RadioStation> favourites);
}

/// Session-only store: the default so widget tests and unsupported platforms
/// behave identically without touching platform channels.
class InMemoryFavouriteStationStore implements FavouriteStationStore {
  Map<String, RadioStation> _data = {};

  @override
  Future<Map<String, RadioStation>> load() async =>
      Map<String, RadioStation>.of(_data);

  @override
  Future<void> save(Map<String, RadioStation> favourites) async {
    _data = Map<String, RadioStation>.of(favourites);
  }
}

/// [SharedPreferences]-backed store used by the real app entrypoint.
class SharedPreferencesFavouriteStationStore implements FavouriteStationStore {
  static const String _key = 'favourite-stations-v1';

  @override
  Future<Map<String, RadioStation>> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return {
        for (final dynamic entry in list)
          if (entry is Map<String, dynamic>)
            if (_stationFromJson(entry) case final RadioStation station)
              station.stationId: station,
      };
    } on FormatException {
      return {};
    }
  }

  @override
  Future<void> save(Map<String, RadioStation> favourites) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final RadioStation s in favourites.values) _stationToJson(s)]),
    );
  }
}

/// Minimal snapshot: identity + what the UI renders. Deliberately not the
/// whole model — schedule/mock-only fields are dropped.
Map<String, dynamic> _stationToJson(RadioStation station) => <String, dynamic>{
      'id': station.id,
      'name': station.name,
      'category': station.category,
      'program': station.program,
      'country': station.country,
      'city': station.city,
      'language': station.language,
      'website': station.website,
      'streamUrl': station.streamUrl,
      'streamType': station.streamType,
      'tags': station.tags,
      'bitrate': station.bitrate,
      'codec': station.codec,
      'logoUrl': station.logoUrl,
      'favicon': station.favicon,
      'isOnline': station.isOnline,
    };

RadioStation? _stationFromJson(Map<String, dynamic> json) {
  final String? name = (json['name'] as String?)?.trim();
  if (name == null || name.isEmpty) return null;
  return RadioStation(
    id: json['id'] as String?,
    name: name,
    category: (json['category'] as String?)?.isNotEmpty == true
        ? json['category'] as String
        : 'Radio',
    program: (json['program'] as String?)?.isNotEmpty == true
        ? json['program'] as String
        : 'LIVE RADIO',
    country: json['country'] as String?,
    city: json['city'] as String?,
    language: json['language'] as String?,
    website: json['website'] as String?,
    streamUrl: json['streamUrl'] as String?,
    streamType: json['streamType'] as String?,
    tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
    bitrate: (json['bitrate'] as num?)?.toInt(),
    codec: json['codec'] as String?,
    logoUrl: json['logoUrl'] as String?,
    favicon: json['favicon'] as String?,
    isOnline: json['isOnline'] is bool ? json['isOnline'] as bool : true,
  );
}
