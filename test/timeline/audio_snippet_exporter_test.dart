import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_over/data/timeline/audio_snippet_exporter.dart';
import 'package:radio_over/models/audio_snippet.dart';

void main() {
  group('AudioSnippetExporter Tests', () {
    test('sliceAudio slices bytes proportionally between start and end', () {
      final Uint8List mockBytes = Uint8List.fromList(List.generate(100, (i) => i));

      final sliced = AudioSnippetExporter.sliceAudio(
        bytes: mockBytes,
        start: const Duration(seconds: 25),
        end: const Duration(seconds: 75),
        totalDuration: const Duration(seconds: 100),
      );

      expect(sliced.length, 50);
      expect(sliced.first, 25);
      expect(sliced.last, 74);
    });

    test('sliceAudio handles zero or clamped duration gracefully', () {
      final Uint8List mockBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final sliced = AudioSnippetExporter.sliceAudio(
        bytes: mockBytes,
        start: Duration.zero,
        end: Duration.zero,
        totalDuration: Duration.zero,
      );

      expect(sliced.isNotEmpty, isTrue);
    });

    test('exportAudioFile writes valid audio file to destination', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp('radio_over_test_');
      final exporter = AudioSnippetExporter(
        getTempDir: () async => tempDir,
      );

      final snippet = AudioSnippet(
        id: 'test-snippet-1',
        userId: 'u1',
        userName: 'Tester',
        podcastId: 'p1',
        podcastName: 'Test Show',
        episodeId: 'e1',
        episodeTitle: 'Test Ep',
        start: const Duration(seconds: 10),
        end: const Duration(seconds: 25),
        caption: 'Memorable quote',
        createdAt: DateTime.now(),
      );

      final File exported = await exporter.exportAudioFile(snippet: snippet);

      expect(await exported.exists(), isTrue);
      expect(await exported.length(), greaterThan(0));
      expect(exported.path, contains('snippet_test-snippet-1.mp3'));

      // Cleanup
      await tempDir.delete(recursive: true);
    });
  });
}
