import '../../models/station.dart';
import 'radio_repository.dart';

/// Deterministic, offline source for development and widget tests. Serves the
/// existing curated [mockStations] set so screens behave identically when the
/// real directory is not available.
class MockRadioRepository implements RadioRepository {
  const MockRadioRepository([this.stations = mockStations]);

  final List<RadioStation> stations;

  Future<List<RadioStation>> _results(List<RadioStation> matching) async => matching;

  @override
  Future<List<RadioStation>> search(String query, {int limit = 25}) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return _results(stations.take(limit).toList());
    final List<RadioStation> hits = stations
        .where((RadioStation s) =>
            s.name.toLowerCase().contains(q) ||
            s.tags.any((String t) => t.toLowerCase().contains(q)))
        .toList();
    return _results(hits.take(limit).toList());
  }

  @override
  Future<List<RadioStation>> byTag(String tag, {int limit = 25}) {
    final String t = tag.trim().toLowerCase();
    final List<RadioStation> hits = t.isEmpty
        ? stations.toList()
        : stations.where((RadioStation s) =>
            s.category.toLowerCase() == t ||
            s.tags.any((String x) => x.toLowerCase() == t)).toList();
    return _results(hits.take(limit).toList());
  }

  @override
  Future<List<RadioStation>> byCountry(String country, {int limit = 25}) {
    final String c = country.trim().toLowerCase();
    final List<RadioStation> hits = c.isEmpty
        ? stations.toList()
        : stations.where((RadioStation s) =>
            (s.country ?? '').toLowerCase() == c).toList();
    return _results(hits.take(limit).toList());
  }

  @override
  Future<List<RadioStation>> popular({int limit = 25}) {
    return _results(stations.take(limit).toList());
  }
}