import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'podcast_directory_repository.dart';

/// Thrown when a repository is used but its build-time credentials were not
/// configured. Callers treat this as "directory unavailable" and fall back.
class CredentialsNotConfigured implements Exception {
  final String provider;
  CredentialsNotConfigured(this.provider);

  @override
  String toString() => 'CredentialsNotConfigured: $provider';
}

/// Backed by the Podcast Index API (podcastindex.org). Requires an API key +
/// secret supplied at build time via `--dart-define`:
///
///     flutter run --dart-define=PODCAST_INDEX_KEY=k \
///                 --dart-define=PODCAST_INDEX_SECRET=s
///
/// Auth is a SHA1(key + secret + unix epoch) signed request per call. The
/// payload is still passed over HTTPS; the signature mainly identifies the
/// caller. Failing that setup, [search] throws [CredentialsNotConfigured] and
/// the caller falls back to the offline mock directory.
class PodcastIndexDirectoryRepository implements PodcastDirectoryRepository {
  PodcastIndexDirectoryRepository({
    http.Client? client,
    this.baseUrl = 'https://api.podcastindex.org/api/1.0',
    String key = const String.fromEnvironment('PODCAST_INDEX_KEY'),
    String secret = const String.fromEnvironment('PODCAST_INDEX_SECRET'),
  })  : _client = client ?? http.Client(),
        _apiKey = key,
        _apiSecret = secret;

  final http.Client _client;
  final String baseUrl;
  final String _apiKey;
  final String _apiSecret;

  bool get _hasCredentials => _apiKey.isNotEmpty && _apiSecret.isNotEmpty;

  @override
  Future<List<PodcastSearchHit>> search(String query, {int limit = 25}) {
    return _hits('/search/byterm', {'q': query, 'max': '$limit'});
  }

  @override
  Future<List<PodcastSearchHit>> popular({int limit = 25}) {
    return _hits('/podcasts/trending', {'max': '$limit'});
  }

  Future<List<PodcastSearchHit>> _hits(String path, Map<String, String> query) async {
    if (!_hasCredentials) throw CredentialsNotConfigured('podcastindex.org');
    final int epoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final Uri uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final http.Response response = await _client.get(
      uri,
      headers: <String, String>{
        'User-Agent': 'radio_over/0.1 (+https://radio-over.example)',
        'X-Auth-Key': _apiKey,
        'X-Auth-Date': '$epoch',
        'Authorization': _signature(epoch),
      },
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ContentSourceException('Podcast Index returned ${response.statusCode} for $path');
    }
    final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> feed = body['feeds'] as List<dynamic>? ?? const [];
    return feed
        .map((dynamic e) => _hitFromJson(e as Map<String, dynamic>))
        .toList();
  }

  String _signature(int epoch) {
    final String plain = '$_apiKey$_apiSecret$epoch';
    return sha1.convert(utf8.encode(plain)).toString();
  }

  PodcastSearchHit _hitFromJson(Map<String, dynamic> json) {
    final List<String> categories = ((json['categories'] as Map<String, dynamic>?)?.values ?? const Iterable<dynamic>.empty())
        .whereType<String>()
        .toList();
    return PodcastSearchHit(
      title: (json['title'] as String?)?.trim() ?? 'Untitled podcast',
      author: (json['author'] as String?)?.trim() ?? 'Unknown',
      description: (json['description'] as String?)?.trim(),
      categories: categories,
      imageUrl: _nonEmpty(json['image'] as String?),
      feedUrl: _nonEmpty(json['url'] as String?),
      directoryId: (json['id'] as num?)?.toString(),
    );
  }

  static String? _nonEmpty(String? value) =>
      (value == null || value.isEmpty) ? null : value;
}