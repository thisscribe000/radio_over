import 'dart:convert';

import 'package:http/http.dart' as http;

import 'podcast_directory_repository.dart';

/// Keyless podcast directory backed by Apple's public podcast catalogue APIs.
///
/// Search and the top-chart feed are free to query and return RSS feed URLs;
/// the RSS repository then supplies the playable episode enclosures.
class ApplePodcastDirectoryRepository implements PodcastDirectoryRepository {
  ApplePodcastDirectoryRepository({
    http.Client? client,
    this.country = 'us',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String country;

  @override
  Future<List<PodcastSearchHit>> search(String query, {int limit = 25}) async {
    final Uri uri = Uri.https('itunes.apple.com', '/search', <String, String>{
      'term': query,
      'media': 'podcast',
      'entity': 'podcast',
      'limit': '$limit',
      'country': country,
    });
    final Map<String, dynamic> body = await _getJson(uri);
    final List<dynamic> results = body['results'] as List<dynamic>? ?? const [];
    return results.whereType<Map<String, dynamic>>().map(_hitFromJson).toList();
  }

  @override
  Future<List<PodcastSearchHit>> popular({int limit = 25}) async {
    final Uri chartUri = Uri.https(
      'rss.applemarketingtools.com',
      '/api/v2/$country/podcasts/top/$limit/podcasts.json',
    );
    final Map<String, dynamic> chart = await _getJson(chartUri);
    final List<dynamic> entries =
        (chart['feed'] as Map<String, dynamic>?)?['results'] as List<dynamic>? ?? const [];
    final List<String> ids = [
      for (final dynamic entry in entries)
        if (entry is Map<String, dynamic> && entry['id'] != null) '${entry['id']}',
    ];
    if (ids.isEmpty) return const [];

    final Map<String, dynamic> lookup = await _getJson(
      Uri.https('itunes.apple.com', '/lookup', <String, String>{
        'id': ids.join(','),
        'entity': 'podcast',
        'country': country,
      }),
    );
    final List<dynamic> results = lookup['results'] as List<dynamic>? ?? const [];
    final Map<String, PodcastSearchHit> byId = {
      for (final dynamic result in results)
        if (result is Map<String, dynamic> && result['collectionId'] != null)
          '${result['collectionId']}': _hitFromJson(result),
    };
    return [for (final String id in ids) if (byId[id] != null) byId[id]!];
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final http.Response response = await _client.get(
      uri,
      headers: const <String, String>{'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ContentSourceException('Apple Podcasts returned ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  PodcastSearchHit _hitFromJson(Map<String, dynamic> json) {
    final String title =
        (json['collectionName'] as String? ?? json['trackName'] as String? ?? 'Untitled podcast').trim();
    return PodcastSearchHit(
      title: title,
      author: (json['artistName'] as String? ?? '').trim(),
      description: (json['collectionDescription'] as String?)?.trim(),
      imageUrl: (json['artworkUrl600'] as String?) ?? (json['artworkUrl100'] as String?),
      feedUrl: (json['feedUrl'] as String?)?.trim(),
      directoryId: (json['collectionId'] ?? json['trackId'])?.toString(),
    );
  }
}
