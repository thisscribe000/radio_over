import 'package:flutter_test/flutter_test.dart';
import 'package:radio_over/search/recent_search_store.dart';
import 'package:radio_over/search/recent_searches.dart';

void main() {
  group('RecentSearches', () {
    test('restores a previously persisted history through a shared store',
        () async {
      final InMemoryRecentSearchStore store = InMemoryRecentSearchStore();
      final RecentSearches searches = RecentSearches(store: store);
      searches.add('bbc');
      searches.add('lagos');
      await Future<void>.delayed(Duration.zero); // fire-and-forget save lands

      expect(await store.load(), ['lagos', 'bbc']);

      // A fresh instance over the same store restores the history.
      final RecentSearches restored = RecentSearches(store: store);
      await restored.restore();
      expect(restored.entries, ['lagos', 'bbc']);
    });

    test('remove and clear persist through the store', () async {
      final InMemoryRecentSearchStore store = InMemoryRecentSearchStore();
      final RecentSearches searches = RecentSearches(store: store);
      searches.add('news');
      searches.add('radio');
      searches.remove('news');
      await Future<void>.delayed(Duration.zero);
      expect(await store.load(), ['radio']);

      searches.clear();
      await Future<void>.delayed(Duration.zero);
      expect(await store.load(), isEmpty);
    });

    test('add/remove/clear mutate and notify', () async {
      final RecentSearches searches = RecentSearches();
      int notifications = 0;
      searches.addListener(() => notifications++);

      searches.add('news');
      searches.add('jazz');
      searches.add('news'); // dedupes + moves to front
      expect(searches.entries, ['news', 'jazz']);
      expect(notifications, 3);

      searches.remove('jazz');
      expect(searches.entries, ['news']);
      expect(notifications, 4);

      searches.clear();
      expect(searches.isEmpty, isTrue);
      expect(notifications, 5);
    });

    test('bounded by the limit, most recent first', () async {
      final RecentSearches searches = RecentSearches(limit: 2);
      searches.add('one');
      searches.add('two');
      searches.add('three');
      expect(searches.entries, ['three', 'two']);
    });

    test('ignores empty and blank terms', () async {
      final RecentSearches searches = RecentSearches();
      searches.add('');
      searches.add('   ');
      expect(searches.isEmpty, isTrue);
    });
  });
}
