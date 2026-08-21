import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radio_over/data/radio/mock_radio_repository.dart';
import 'package:radio_over/data/radio/radio_browser_repository.dart';
import 'package:radio_over/data/radio/radio_repository.dart';
import 'package:radio_over/models/station.dart';

Map<String, dynamic> _stationJson([Map<String, dynamic>? overrides]) {
  return <String, dynamic>{
    'stationuuid': 'abc-123',
    'name': 'Jazz FM',
    'tags': 'jazz, news, london',
    'country': 'United Kingdom',
    'city': 'London',
    'language': 'english',
    'homepage': 'https://jazz.fm',
    'favicon': 'https://jazz.fm/favicon.png',
    'url': 'http://listen.jazz.fm/stream',
    'url_resolved': 'http://edge/jazz.mp3',
    'bitrate': 128,
    'codec': 'MP3',
    'isOnline': true,
    'is_https': true,
    'nowplaying': 'Late Night Session',
    ...?overrides,
  };
}

void main() {
  group('radioBrowserStationFromJson', () {
    test('maps a full station record onto the app model', () {
      final RadioStation station = radioBrowserStationFromJson(_stationJson());

      expect(station.id, 'abc-123');
      expect(station.name, 'Jazz FM');
      expect(station.category, 'Jazz');
      expect(station.program, 'Late Night Session');
      expect(station.location, 'London, United Kingdom');
      expect(station.language, 'english');
      expect(station.website, 'https://jazz.fm');
      expect(station.codec, 'MP3');
      expect(station.bitrate, 128);
      expect(station.isOnline, isTrue);
      expect(station.tags, ['jazz', 'news', 'london']);
    });

    test('switches an http stream URL to https when the feed is https', () {
      final RadioStation station = radioBrowserStationFromJson(_stationJson());
      expect(station.streamUrl, 'https://listen.jazz.fm/stream');
      expect(station.logoUrl, 'https://jazz.fm/favicon.png');
    });

    test('accepts numeric isOnline flags and empty nowplaying', () {
      final RadioStation station = radioBrowserStationFromJson(_stationJson({
        'isOnline': 1,
        'is_https': 0,
        'nowplaying': '',
      }));
      expect(station.isOnline, isTrue);
      expect(station.streamUrl, 'http://listen.jazz.fm/stream');
      expect(station.program, 'LIVE RADIO');
    });

    test('survives a minimal record', () {
      final RadioStation station = radioBrowserStationFromJson({'name': '   '});
      expect(station.name, 'Untitled station');
      expect(station.category, 'Radio');
      expect(station.streamUrl, isNull);
      expect(station.isOnline, isTrue);
    });

    test('derives the category from tags when unknown', () {
      final RadioStation station = radioBrowserStationFromJson(_stationJson({'tags': 'techno, berlin'}));
      expect(station.category, 'Techno');
    });
  });

  group('RadioBrowserRepository', () {
    test('searches with the right query and decodes results', () async {
      Uri? captured;
      final http.Client client = MockClient((http.Request request) async {
        captured = request.url;
        return http.Response(
          jsonEncode([_stationJson()]),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final RadioRepository repo = RadioBrowserRepository(client: client);

      final List<RadioStation> hits = await repo.search('jazz');
      expect(captured!.path, endsWith('/stations/search'));
      expect(captured!.queryParameters['name'], 'jazz');
      expect(captured!.queryParameters['hidebroken'], 'true');
      expect(hits, hasLength(1));
      expect(hits.first.name, 'Jazz FM');
    });

    test('builds the byTag and popular endpoints', () async {
      final List<String> paths = <String>[];
      final http.Client client = MockClient((http.Request request) async {
        paths.add(request.url.path);
        return http.Response('[]', 200);
      });
      final RadioBrowserRepository repo = RadioBrowserRepository(client: client);

      await repo.byTag('news');
      await repo.popular();
      expect(paths, [
        endsWith('/stations/bytag/news'),
        endsWith('/stations/topvote'),
      ]);
    });

    test('builds the byCountry endpoint with an encoded country name', () async {
      final List<String> paths = <String>[];
      final List<String> queries = <String>[];
      final http.Client client = MockClient((http.Request request) async {
        paths.add(request.url.path);
        queries.add(request.url.queryParameters['hidebroken'] ?? '');
        return http.Response(jsonEncode([_stationJson()]), 200);
      });
      final RadioBrowserRepository repo = RadioBrowserRepository(client: client);

      final List<RadioStation> hits = await repo.byCountry('United Kingdom');
      expect(paths.single, endsWith('/stations/bycountry/United%20Kingdom'));
      expect(queries.single, 'true');
      expect(hits, hasLength(1));
      expect(hits.first.country, 'United Kingdom');
    });

    test('byTag serves mapped stations', () async {
      final http.Client client = MockClient(
        (request) async => http.Response(jsonEncode([_stationJson()]), 200),
      );
      final RadioBrowserRepository repo = RadioBrowserRepository(client: client);

      final List<RadioStation> hits = await repo.byTag('jazz');
      expect(hits, hasLength(1));
      expect(hits.first.id, 'abc-123');
    });

    test('throws a ContentSourceException on a bad status', () async {
      final http.Client client = MockClient((request) async => http.Response('oops', 503));
      final RadioBrowserRepository repo = RadioBrowserRepository(client: client);
      expect(
        () => repo.search('jazz'),
        throwsA(isA<ContentSourceException>()),
      );
    });
  });

  group('MockRadioRepository', () {
    test('serves the curated catalogue offline', () async {
      const MockRadioRepository repo = MockRadioRepository();
      final List<RadioStation> all = await repo.popular();
      expect(all, isNotEmpty);
      final List<RadioStation> hits = await repo.search('jazz');
      expect(hits, isNotEmpty);
      expect(hits.first.name.toLowerCase(), contains('jazz'));
    });
  });
}