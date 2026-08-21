import '../../models/podcast_episode.dart';
import 'podcast_directory_repository.dart';

/// Offline search over the curated mock catalogue, mirroring how the real
/// directory finds shows. Search hits carry no episodes — just like the real
/// thing — so the feed repository resolves full series.
class MockPodcastDirectoryRepository implements PodcastDirectoryRepository {
  const MockPodcastDirectoryRepository({this.series = mockPodcasts});

  final List<PodcastSeries> series;

  Future<List<PodcastSearchHit>> _hits(Iterable<PodcastSeries> shows) async => [
        for (final PodcastSeries s in shows)
          PodcastSearchHit(
            title: s.name,
            author: s.publisher,
            description: s.description,
            categories: [s.category],
            imageUrl: s.imageUrl,
            feedUrl: s.feedUrl,
            directoryId: s.id,
          ),
      ];

  @override
  Future<List<PodcastSearchHit>> search(String query, {int limit = 25}) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return _hits(series.take(limit));
    return _hits(series.where((PodcastSeries s) =>
        s.name.toLowerCase().contains(q) ||
        s.publisher.toLowerCase().contains(q)).take(limit));
  }

  @override
  Future<List<PodcastSearchHit>> popular({int limit = 25}) {
    return _hits(series.take(limit));
  }
}