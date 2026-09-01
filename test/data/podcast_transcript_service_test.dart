import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radio_over/data/podcasts/podcast_transcript_service.dart';
import 'package:radio_over/models/podcast_episode.dart';

void main() {
  group('PodcastTranscriptService - WebVTT & SRT parsing', () {
    test('parses standard WebVTT format', () {
      const String sampleVtt = '''WEBVTT

00:00:01.500 --> 00:00:04.000
Welcome to the show.

00:00:04.500 --> 00:00:08.250
<v Speaker 1>Today we are exploring live chapters and transcripts.</v>
''';

      final List<PodcastCaption> captions =
          PodcastTranscriptService.parseWebVttOrSrt(sampleVtt);
      expect(captions.length, 2);
      expect(captions[0].start, const Duration(seconds: 1, milliseconds: 500));
      expect(captions[0].text, 'Welcome to the show.');
      expect(captions[1].start, const Duration(seconds: 4, milliseconds: 500));
      expect(captions[1].text, 'Today we are exploring live chapters and transcripts.');
    });

    test('parses SRT format with comma milliseconds', () {
      const String sampleSrt = '''1
00:01:10,200 --> 00:01:15,000
First SRT line text.

2
00:01:16,000 --> 00:01:20,500
Second SRT line text.
''';

      final List<PodcastCaption> captions =
          PodcastTranscriptService.parseWebVttOrSrt(sampleSrt);
      expect(captions.length, 2);
      expect(captions[0].start, const Duration(minutes: 1, seconds: 10, milliseconds: 200));
      expect(captions[0].text, 'First SRT line text.');
      expect(captions[1].start, const Duration(minutes: 1, seconds: 16));
      expect(captions[1].text, 'Second SRT line text.');
    });

    test('parses JSON transcript format', () {
      const String jsonTranscript = '''{
        "version": "1.0.0",
        "segments": [
          { "startTime": 12.5, "body": "JSON line one" },
          { "startTime": 30.0, "body": "JSON line two" }
        ]
      }''';

      final List<PodcastCaption> captions =
          PodcastTranscriptService.parseTranscript(jsonTranscript);
      expect(captions.length, 2);
      expect(captions[0].start, const Duration(seconds: 12, milliseconds: 500));
      expect(captions[0].text, 'JSON line one');
      expect(captions[1].start, const Duration(seconds: 30));
      expect(captions[1].text, 'JSON line two');
    });
  });

  group('PodcastTranscriptService - Podcast 2.0 Chapters JSON', () {
    test('parses standard JSON chapters', () {
      const String sampleChaptersJson = '''{
        "version": "1.2.0",
        "chapters": [
          { "startTime": 0, "title": "Introduction" },
          { "startTime": 180.5, "title": "Deep Dive Topic", "description": "Extended talk on design" },
          { "startTime": 600, "title": "Closing Remarks" }
        ]
      }''';

      final List<PodcastChapter> chapters =
          PodcastTranscriptService.parseChaptersJson(sampleChaptersJson);
      expect(chapters.length, 3);
      expect(chapters[0].title, 'Introduction');
      expect(chapters[0].start, Duration.zero);
      expect(chapters[1].title, 'Deep Dive Topic');
      expect(chapters[1].start, const Duration(minutes: 3, milliseconds: 500));
      expect(chapters[1].description, 'Extended talk on design');
      expect(chapters[2].title, 'Closing Remarks');
      expect(chapters[2].start, const Duration(minutes: 10));
    });
  });

  group('PodcastTranscriptService - HTTP fetching and caching', () {
    test('loads and caches captions from URL', () async {
      int requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        return http.Response(
          'WEBVTT\n\n00:00:02.000 --> 00:00:05.000\nFetched caption.',
          200,
        );
      });

      final service = PodcastTranscriptService(client: client);
      final List<PodcastCaption>? firstCall =
          await service.loadCaptions('https://example.com/transcript.vtt');
      expect(firstCall, isNotNull);
      expect(firstCall!.first.text, 'Fetched caption.');
      expect(requestCount, 1);

      // Second call hits in-memory cache
      final List<PodcastCaption>? secondCall =
          await service.loadCaptions('https://example.com/transcript.vtt');
      expect(secondCall, isNotNull);
      expect(secondCall!.first.text, 'Fetched caption.');
      expect(requestCount, 1);
    });

    test('loads and caches chapters from URL', () async {
      int requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        return http.Response(
          '{"version": "1.2.0", "chapters": [{"startTime": 10, "title": "Fetched Chapter"}]}',
          200,
        );
      });

      final service = PodcastTranscriptService(client: client);
      final List<PodcastChapter>? firstCall =
          await service.loadChapters('https://example.com/chapters.json');
      expect(firstCall, isNotNull);
      expect(firstCall!.first.title, 'Fetched Chapter');
      expect(requestCount, 1);

      // Second call hits cache
      final List<PodcastChapter>? secondCall =
          await service.loadChapters('https://example.com/chapters.json');
      expect(secondCall, isNotNull);
      expect(secondCall!.first.title, 'Fetched Chapter');
      expect(requestCount, 1);
    });
  });
}
