import '../../models/station.dart';

/// Thrown when a repository cannot serve a request; callers treat it as a
/// graceful "no content" rather than a crash (e.g. directory down, no creds).
class ContentSourceException implements Exception {
  ContentSourceException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'ContentSourceException: $message';
}

/// Contract for any remote source of live radio stations.
///
/// The app depends on this interface — not on Radio Browser or the mock
/// dataset — so the source can be swapped without touching the UI.
abstract class RadioRepository {
  /// Stations whose name/tags match [query], most relevant first.
  Future<List<RadioStation>> search(String query, {int limit = 25});

  /// Popular/curated stations in a category or tag (empty = general popular).
  Future<List<RadioStation>> byTag(String tag, {int limit = 25});

  /// Stations broadcasting from [country] (e.g. "Germany"), most popular
  /// first. Drives the home screen's country browsing.
  Future<List<RadioStation>> byCountry(String country, {int limit = 25});

  /// Frequently-listened/popular stations for the home screen.
  Future<List<RadioStation>> popular({int limit = 25});
}