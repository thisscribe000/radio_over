import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/station.dart';
import 'radio_repository.dart';

/// Radio Browser's own genre vocabulary, used to derive a [RadioStation.category]
/// from the free-form `tags` array. Anything unlisted becomes "Radio".
const Set<String> radioBrowserCategories = {
  'news', 'talk', 'sport', 'music', 'culture', 'arts', 'science', 'technology',
  'education', 'comedy', 'community', 'jazz', 'classical', 'rock', 'pop',
  'hip-hop', 'hip hop', 'electronic', 'dance', 'country', 'folk', 'reggae',
  'spiritual', 'religious', 'religious music', 'kids',
};

/// Maps a raw Radio Browser station JSON object to the app's [RadioStation].
/// Pure and sync so it is unit-testable with plain fixtures.
RadioStation radioBrowserStationFromJson(Map<String, dynamic> json) {
  final String name = _nonEmptyTrim(json['name'] as String?) ?? 'Untitled station';
  final List<String> rawTags = (json['tags'] as String?)?.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList() ?? const [];

  String category = 'Radio';
  for (final String t in rawTags) {
    if (radioBrowserCategories.contains(t.toLowerCase())) {
      category = _titleCase(t);
      break;
    }
  }
  if (category == 'Radio' && rawTags.isNotEmpty) {
    category = _titleCase(rawTags.first);
  }

  final String? url = json['url'] as String?;
  final String? language = (json['language'] as String?)?.trim();
  final String? country = _countryTitleCase(json['country'] as String?);
  final String? city = (json['city'] as String?)?.trim();
  final String? homepage = json['homepage'] as String?;
  final String? favicon = json['favicon'] as String?;
  final String? logo = json['favicon'] as String?;
  final int? bitrate = (json['bitrate'] as num?)?.toInt();
  final String? codec = json['codec'] as String?;
  final dynamic online = json['isOnline'] ?? json['is_online'];
  final bool isOnline = online is bool ? online : (online == null ? true : online == 1);
  final dynamic isHttpsRaw = json['is_https'];
  final bool isHttps = isHttpsRaw is bool ? isHttpsRaw : isHttpsRaw == 1;

  final String streamUrl = isHttps && (url?.startsWith('http://') ?? false)
      ? 'https://${url!.substring(7)}'
      : (url ?? '');

  return RadioStation(
    id: (json['stationuuid'] as String?) ?? name,
    name: name,
    category: category,
    program: json['nowplaying'] is String && (json['nowplaying'] as String).isNotEmpty
        ? (json['nowplaying'] as String).trim()
        : 'LIVE RADIO',
    country: country,
    city: city,
description: rawTags.isNotEmpty
        ? null
        : 'Live radio from $name. Tune in to hear the current programme.',
    language: language,
    website: homepage,
    streamUrl: streamUrl.isEmpty ? null : streamUrl,
    streamType: json['url_resolved'] as String?,
    tags: rawTags,
    bitrate: bitrate,
    codec: codec,
    logoUrl: _firstNonEmpty(logo, favicon),
    favicon: favicon,
    isOnline: isOnline,
    nowPlaying: json['nowplaying'] as String?,
  );
}

String _firstNonEmpty(String? a, String? b) => (a == null || a.isEmpty) ? (b ?? '') : a;

String? _nonEmptyTrim(String? value) {
  if (value == null) return null;
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _titleCase(String s) {
  if (s.isEmpty) return s;
  return s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

String? _countryTitleCase(String? s) {
  if (s == null) return null;
  return s.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}

/// Backed by the public Radio Browser API (radio-browser.info). No API key.
///
/// Base host rotates; `de1` is the canonical default but any server mirrors.
class RadioBrowserRepository implements RadioRepository {
  RadioBrowserRepository({
    http.Client? client,
    this.baseUrl = 'https://de1.api.radio-browser.info/json',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  @override
  Future<List<RadioStation>> search(String query, {int limit = 25}) {
    return _fetchStations('/stations/search', {
      'name': query,
      'limit': '$limit',
      'hidebroken': 'true',
    });
  }

  @override
  Future<List<RadioStation>> byTag(String tag, {int limit = 25}) {
    return _fetchStations('/stations/bytag/${Uri.encodeComponent(tag)}', {
      'hidebroken': 'true',
      'limit': '$limit',
    });
  }

  @override
  Future<List<RadioStation>> byCountry(String country, {int limit = 25}) {
    return _fetchStations('/stations/bycountry/${Uri.encodeComponent(country)}', {
      'hidebroken': 'true',
      'limit': '$limit',
    });
  }

  @override
  Future<List<RadioStation>> popular({int limit = 25}) {
    return _fetchStations('/stations/topvote', {
      'hidebroken': 'true',
      'limit': '$limit',
    });
  }

  Future<List<RadioStation>> _fetchStations(String path, Map<String, String> query) async {
    final Uri uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final http.Response response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ContentSourceException(
        'Radio Browser returned ${response.statusCode} for $path',
      );
    }
    final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((dynamic e) => radioBrowserStationFromJson(e as Map<String, dynamic>))
        .toList();
  }
}