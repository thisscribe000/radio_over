import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/podcast_episode.dart';
import 'firebase_service.dart';

/// Database repository managing Creator Portal operations for direct podcast hosting.
///
/// Communicates with Cloud Firestore under:
/// `/creators/{creatorId}/shows/{showId}` and its subcollection `/episodes`.
class CreatorHostingRepository {
  final FirebaseFirestore _firestore;

  CreatorHostingRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? (FirebaseService.isActive ? FirebaseFirestore.instance : null) as dynamic;

  /// Retrieves all shows created/hosted by the specified creator.
  Future<List<PodcastSeries>> fetchMyHostedShows(String creatorId) async {
    if (!FirebaseService.isActive) return [];

    final QuerySnapshot snapshot = await _firestore
        .collection('creators')
        .doc(creatorId)
        .collection('shows')
        .get();

    final List<PodcastSeries> shows = [];
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Fetch episodes subcollection
      final episodes = await fetchHostedEpisodes(creatorId, doc.id);

      shows.add(
        PodcastSeries(
          id: doc.id,
          name: data['name'] as String? ?? '',
          category: data['category'] as String? ?? 'Talk',
          publisher: data['publisher'] as String? ?? '',
          description: data['description'] as String? ?? '',
          imageUrl: data['imageUrl'] as String?,
          feedUrl: data['feedUrl'] as String?,
          episodes: episodes,
        ),
      );
    }
    return shows;
  }

  /// Creates/saves a new podcast show under direct hosting.
  Future<void> createHostedShow(String creatorId, PodcastSeries show) async {
    if (!FirebaseService.isActive) return;

    await _firestore
        .collection('creators')
        .doc(creatorId)
        .collection('shows')
        .doc(show.id)
        .set({
      'name': show.name,
      'category': show.category,
      'publisher': show.publisher,
      'description': show.description,
      'imageUrl': show.imageUrl,
      'feedUrl': show.feedUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Retrieves all episodes hosted under a specific show.
  Future<List<PodcastEpisode>> fetchHostedEpisodes(String creatorId, String showId) async {
    if (!FirebaseService.isActive) return [];

    final QuerySnapshot snapshot = await _firestore
        .collection('creators')
        .doc(creatorId)
        .collection('shows')
        .doc(showId)
        .collection('episodes')
        .orderBy('publishedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return PodcastEpisode(
        id: doc.id,
        podcastId: showId,
        podcastName: data['podcastName'] as String? ?? '',
        title: data['title'] as String? ?? '',
        about: data['description'] as String? ?? '',
        audioUrl: data['audioUrl'] as String?,
        duration: Duration(seconds: data['durationSeconds'] as int? ?? 0),
        published: data['publishedDate'] as String? ?? '',
      );
    }).toList();
  }

  /// Adds a new episode to a hosted show.
  Future<void> addHostedEpisode({
    required String creatorId,
    required String showId,
    required PodcastEpisode episode,
  }) async {
    if (!FirebaseService.isActive) return;

    await _firestore
        .collection('creators')
        .doc(creatorId)
        .collection('shows')
        .doc(showId)
        .collection('episodes')
        .doc(episode.id)
        .set({
      'podcastName': episode.podcastName,
      'title': episode.title,
      'description': episode.about,
      'audioUrl': episode.audioUrl,
      'durationSeconds': episode.duration.inSeconds,
      'publishedDate': episode.published,
      'publishedAt': FieldValue.serverTimestamp(),
    });
  }
}
