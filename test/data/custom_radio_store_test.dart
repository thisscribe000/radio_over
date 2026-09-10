import 'package:flutter_test/flutter_test.dart';
import 'package:radio_over/data/radio/custom_radio_store.dart';
import 'package:radio_over/models/station.dart';

void main() {
  group('CustomRadioStore Tests', () {
    test('InMemoryCustomRadioStore saves, lists, and removes stations', () async {
      final store = InMemoryCustomRadioStore();

      expect(await store.load(), isEmpty);

      final station1 = const RadioStation(
        id: 'custom_1',
        name: 'Chillout Lounge',
        category: 'Ambient',
        streamUrl: 'https://stream.example.com/chill.mp3',
        program: 'LIVE STREAM',
      );

      final station2 = const RadioStation(
        id: 'custom_2',
        name: 'Electro FM',
        category: 'Electronic',
        streamUrl: 'https://stream.example.com/electro.aac',
        program: 'LIVE STREAM',
      );

      await store.addStation(station1);
      await store.addStation(station2);

      final list = await store.load();
      expect(list.length, 2);
      expect(list[0].name, 'Electro FM'); // Most recent first
      expect(list[1].name, 'Chillout Lounge');

      await store.removeStation('custom_1');
      final updated = await store.load();
      expect(updated.length, 1);
      expect(updated[0].name, 'Electro FM');
    });
  });
}
