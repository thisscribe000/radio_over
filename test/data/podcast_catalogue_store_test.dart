import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:radio_over/models/podcast_episode.dart';
import 'package:radio_over/data/podcasts/podcast_catalogue_store.dart';

void main() {
  group('PodcastSeries & PodcastEpisode JSON serialization', () {
    test('serializes and deserializes correctly', () {
      final PodcastEpisode episode = PodcastEpisode(
        id: 'ep-1',
        podcastId: 'show-1',
        podcastName: 'My Podcast',
        title: 'Episode 1',
        duration: const Duration(minutes: 45),
        episodeNumber: 1,
        published: 'Aug 30',
        about: 'This is the description',
        position: const Duration(minutes: 10),
        transcriptAvailable: true,
        audioUrl: 'https://example.com/ep1.mp3',
        guid: 'guid-ep-1',
        imageUrl: 'https://example.com/ep1.jpg',
      );

      final PodcastSeries series = PodcastSeries(
        id: 'show-1',
        name: 'My Podcast',
        category: 'Technology',
        publisher: 'Antigravity Team',
        description: 'A show about code',
        frequency: 'Weekly',
        imageUrl: 'https://example.com/show.jpg',
        feedUrl: 'https://example.com/feed.xml',
        feedAuthor: 'Author Name',
        episodes: [episode],
      );

      // Verify episode serialization
      final Map<String, dynamic> epJson = episode.toJson();
      final PodcastEpisode epDeserialized = PodcastEpisode.fromJson(epJson);
      expect(epDeserialized.id, episode.id);
      expect(epDeserialized.podcastId, episode.podcastId);
      expect(epDeserialized.podcastName, episode.podcastName);
      expect(epDeserialized.title, episode.title);
      expect(epDeserialized.duration, episode.duration);
      expect(epDeserialized.episodeNumber, episode.episodeNumber);
      expect(epDeserialized.published, episode.published);
      expect(epDeserialized.about, episode.about);
      expect(epDeserialized.position, episode.position);
      expect(epDeserialized.transcriptAvailable, episode.transcriptAvailable);
      expect(epDeserialized.audioUrl, episode.audioUrl);
      expect(epDeserialized.guid, episode.guid);
      expect(epDeserialized.imageUrl, episode.imageUrl);

      // Verify series serialization
      final Map<String, dynamic> seriesJson = series.toJson();
      final PodcastSeries seriesDeserialized = PodcastSeries.fromJson(seriesJson);
      expect(seriesDeserialized.id, series.id);
      expect(seriesDeserialized.name, series.name);
      expect(seriesDeserialized.category, series.category);
      expect(seriesDeserialized.publisher, series.publisher);
      expect(seriesDeserialized.description, series.description);
      expect(seriesDeserialized.frequency, series.frequency);
      expect(seriesDeserialized.imageUrl, series.imageUrl);
      expect(seriesDeserialized.feedUrl, series.feedUrl);
      expect(seriesDeserialized.feedAuthor, series.feedAuthor);
      expect(seriesDeserialized.episodes.length, 1);
      expect(seriesDeserialized.episodes.first.id, episode.id);
    });
  });

  group('PodcastCatalogueStore implementations', () {
    test('InMemoryPodcastCatalogueStore loads and saves', () async {
      final PodcastCatalogueStore store = InMemoryPodcastCatalogueStore();
      expect(await store.load(), isEmpty);

      final PodcastSeries series = PodcastSeries(
        id: 'show-1',
        name: 'My Podcast',
        category: 'Tech',
        publisher: 'Publisher',
        description: 'Description',
        episodes: const [],
      );

      await store.save([series]);
      final List<PodcastSeries> loaded = await store.load();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'show-1');
    });

    test('SharedPreferencesPodcastCatalogueStore loads and saves', () async {
      SharedPreferences.setMockInitialValues({});
      final PodcastCatalogueStore store = SharedPreferencesPodcastCatalogueStore();
      expect(await store.load(), isEmpty);

      final PodcastSeries series = PodcastSeries(
        id: 'show-2',
        name: 'Persisted Podcast',
        category: 'News',
        publisher: 'Host',
        description: 'Info',
        episodes: const [],
      );

      await store.save([series]);
      final List<PodcastSeries> loaded = await store.load();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'show-2');
      expect(loaded.first.name, 'Persisted Podcast');
    });
  });
}
