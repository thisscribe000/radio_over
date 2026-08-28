import 'package:flutter_test/flutter_test.dart';

import 'package:radio_over/data/content_scope.dart';
import 'package:radio_over/data/podcasts/mock_podcast_directory_repository.dart';
import 'package:radio_over/data/podcasts/mock_podcast_feed_repository.dart';
import 'package:radio_over/data/radio/radio_repository.dart';
import 'package:radio_over/models/station.dart';

/// A controlled [RadioRepository] so tests can drive exactly what a "live"
/// Radio Browser load returns.
class _FakeRadioRepository implements RadioRepository {
  _FakeRadioRepository(this.hits);

  final List<RadioStation> hits;

  @override
  Future<List<RadioStation>> search(String query, {int limit = 25}) async => hits;
  @override
  Future<List<RadioStation>> byTag(String tag, {int limit = 25}) async => hits;
  @override
  Future<List<RadioStation>> byCountry(String country, {int limit = 25}) async => hits;
  @override
  Future<List<RadioStation>> popular({int limit = 25}) async => hits;
}

/// A live scope (isLive == true) that pins Loveworld Radio and serves [hits]
/// as the live Radio Browser catalogue.
AppContent liveScope(List<RadioStation> hits) => AppContent(
      radio: _FakeRadioRepository(hits),
      podcastDirectory: const MockPodcastDirectoryRepository(),
      podcastFeeds: const MockPodcastFeedRepository(),
      isLive: true,
      pinnedStation: loveworldRadioStation,
    );

const RadioStation _love = loveworldRadioStation;

const RadioStation _bbc = RadioStation(
  id: 'bbc-world-service',
  name: 'BBC World Service',
  category: 'News',
  program: 'World News Today',
);

const RadioStation _npr = RadioStation(
  id: 'npr',
  name: 'NPR',
  category: 'News',
  program: 'Morning Edition',
);

void main() {
  test('pinned Loveworld is first after a successful live load', () async {
    final AppContent content = liveScope([_bbc, _npr]);
    await content.loadRadio();
    expect(content.stations.first, same(_love));
    expect(content.stations[0].stationId, 'loveworld-radio');
  });

  test('pins Loveworld even when Radio Browser does not return it', () async {
    final AppContent content = liveScope([_bbc, _npr]);
    await content.loadRadio();
    expect(content.stations, hasLength(3));
    expect(content.stations[0].stationId, 'loveworld-radio');
    expect(content.stations[1], same(_bbc));
    expect(content.stations[2], same(_npr));
  });

  test('dedupes a live Loveworld result sharing the same station id', () async {
    // Radio Browser returns a station with the same stable id as Loveworld.
    final RadioStation liveLoveworld = const RadioStation(
      id: 'loveworld-radio',
      name: 'Loveworld Radio',
      category: 'Gospel',
      program: 'Different Programme',
    );
    final AppContent content = liveScope([liveLoveworld, _bbc]);
    await content.loadRadio();

    // Only one Loveworld appears, and it is the pinned instance at index 0.
    final List<RadioStation> stations = content.stations;
    final int loveCount =
        stations.where((s) => s.stationId == 'loveworld-radio').length;
    expect(loveCount, 1);
    expect(stations.first, same(_love));
    // The live duplicate instance is dropped, the other station preserved.
    expect(stations.length, 2);
    expect(stations[1], same(_bbc));
  });

  test('duplicate handling does not touch unrelated stations with similar names',
      () async {
    // Radio Browser returns a different Gospel station (not Loveworld id).
    const RadioStation spirit = RadioStation(
      id: 'the-spirit',
      name: 'The Spirit',
      category: 'Gospel',
      program: 'Gospel Hour',
    );
    final AppContent content = liveScope([_bbc, spirit]);
    await content.loadRadio();

    expect(content.stations[0].stationId, 'loveworld-radio');
    expect(content.stations[1], same(_bbc));
    expect(content.stations[2], same(spirit));
  });

  test('featured station resolves to pinned Loveworld after live load', () async {
    final AppContent content = liveScope([_bbc, _npr]);
    await content.loadRadio();
    expect(content.stations.first, same(_love));
    expect(content.stations.first.stationId, loveworldRadioStation.stationId);
  });

  test('pinned Loveworld survives a forced refresh', () async {
    final AppContent content = liveScope([_bbc]);
    await content.loadRadio();
    expect(content.stations.first, same(_love));

    await content.loadRadio(force: true);
    expect(content.stations.first, same(_love));
    expect(content.stations.length, 2);
  });

  test('offline fallback keeps pinned Loveworld when live load fails', () async {
    // A repository that throws keeps the seeded catalogue; the pinned station
    // must still be present at the front.
    final AppContent content = AppContent(
      radio: _ThrowingRadioRepository(),
      podcastDirectory: const MockPodcastDirectoryRepository(),
      podcastFeeds: const MockPodcastFeedRepository(),
      isLive: true,
      pinnedStation: loveworldRadioStation,
    );
    await content.loadRadio();
    expect(content.stations, isNotEmpty);
    expect(content.stations.first, same(_love));
  });

  test('Loveworld uses the verified live stream mount', () {
    // The live endpoint is the `lwradio` mount (currently 200 audio/mpeg);
    // `lwradio2` does not exist and returns 404 "Stream not found".
    expect(loveworldRadioStation.streamUrl,
        'https://radio.superfm963.com/proxy/lwradio/stream');
  });
}

class _ThrowingRadioRepository implements RadioRepository {
  @override
  Future<List<RadioStation>> search(String query, {int limit = 25}) async =>
      throw Exception('down');
  @override
  Future<List<RadioStation>> byTag(String tag, {int limit = 25}) async =>
      throw Exception('down');
  @override
  Future<List<RadioStation>> byCountry(String country, {int limit = 25}) async =>
      throw Exception('down');
  @override
  Future<List<RadioStation>> popular({int limit = 25}) async =>
      throw Exception('down');
}
