import 'package:http/http.dart' as http;

import '../../models/podcast_episode.dart';
import 'podcast_feed_repository.dart';

/// Deliberately offline: resolving a "feed" just returns the matching series
/// from the curated mock catalogue so development and widget tests behave
/// like the real thing without a network.
class MockPodcastFeedRepository implements PodcastFeedRepository {
  const MockPodcastFeedRepository({this.series = mockPodcasts});

  final List<PodcastSeries> series;

  @override
  Future<PodcastSeries> feed(
    String feedUrl, {
    String? preferredId,
    String? preferredName,
    String? preferredAuthor,
    String? preferredImageUrl,
  }) async {
    for (final PodcastSeries show in series) {
      if (show.feedUrl == feedUrl) return show;
      if (preferredId != null && show.id == preferredId) return show;
      if (preferredName != null && show.name == preferredName) return show;
    }
    throw http.ClientException('Mock feed unknown: $feedUrl');
  }
}