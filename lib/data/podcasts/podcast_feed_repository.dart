import 'package:http/http.dart' as http;

import '../../models/podcast_episode.dart';
import '../radio/radio_repository.dart';
import 'rss_podcast_parser.dart';

/// Resolves a full [PodcastSeries] (with episodes) from an RSS feed URL.
abstract class PodcastFeedRepository {
  /// Fetches and parses [feedUrl]. The preferred fields let a directory hit
  /// and its resolved feed converge on one stable identity.
  Future<PodcastSeries> feed(
    String feedUrl, {
    String? preferredId,
    String? preferredName,
    String? preferredAuthor,
    String? preferredImageUrl,
  });
}

/// Production feed repository: HTTP + [RssPodcastParser]. No auth needed.
class RssPodcastFeedRepository implements PodcastFeedRepository {
  RssPodcastFeedRepository({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  final RssPodcastParser _parser = const RssPodcastParser();

  @override
  Future<PodcastSeries> feed(
    String feedUrl, {
    String? preferredId,
    String? preferredName,
    String? preferredAuthor,
    String? preferredImageUrl,
  }) async {
    final http.Response response = await _client.get(
      Uri.parse(feedUrl),
      headers: const <String, String>{'Accept': 'application/rss+xml, application/xml, text/xml, */*'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ContentSourceException('Feed ${response.statusCode}: $feedUrl');
    }
    return _parser.parseFeed(
      response.body,
      preferredId: preferredId,
      preferredName: preferredName,
      preferredAuthor: preferredAuthor,
      preferredImageUrl: preferredImageUrl,
    );
  }
}