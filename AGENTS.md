# radio_over — Project Context & Build Log

Flutter audio app: radio + podcasts. In-memory state on `PlaybackController` (a plain `ChangeNotifier`), no persistence/backend/state-management library. Widget-test driven (`flutter test`), analyzer clean.

## Build status
- **123 tests pass, `flutter analyze` clean** (as of Sleep Timer completion).
- Radio + Podcast saving/history/downloads unified on `PlaybackController`.
- Library screen (third shell tab), Listening History screen, and global Sleep Timer built and wired.

## Architecture rules
- `PlaybackController` is the single source of truth: `audioType`/`status`/`currentStation`/`currentEpisode`, shared stores `favouriteStations`, `savedShows`, `savedEpisodes`, `downloadedEpisodes`, `recentHistory` (bounded `List<ListenRecord>`), and `listeningHistory` (bounded `List<ListeningHistoryItem>`, cap `maxListeningHistoryEntries = 150`, deduped, references content by id).
- `ListenRecord` (models/playback.dart) embeds station/episode; `ListeningHistoryItem` stores `id/contentType/contentId/listenedAt/durationListened/playbackPosition` only.
- Timer rule in tests: unmount tree (`pumpWidget(SizedBox())`) before `controller.dispose()` or the 1s playback/sleep tickers trip `!timersPending`.
- `PlaybackController({DateTime Function()? clock})` injects the clock for deterministic sleep-timer expiry tests (defaults to `DateTime.now`).
- `AppShell` uses an `IndexedStack` (hidden tabs stay mounted + findable); screens must gate off-tab content or scope test finders (`find.descendant`).
- Mini players: radio strip is per-screen top slot (Library/History render their own, gated on tab `active`); podcast strip is shell bottom slot.
- Widget-test font is Ahem; `RadioMiniPlayer` renders station name uppercased.
- Lazy ListView rows need `scrollUntilVisible`/`resetToTop` helpers before asserting below the fold.
- Dialog/sheet widgets live in the root navigator overlay — use unscoped finders for them.

## Navigation
- Shell tabs: RADIO(0), PODCASTS(1), LIBRARY(2) — keys `tab-<label>`.
- Player routes pushed over shell: `RadioPlayerScreen(controller)`, `PodcastPlayerScreen(controller)`, `StationDetailScreen(station, controller)`, `PodcastDetailScreen(show, controller)`, `SearchScreen(controller)`.
- Library → History: `library-history` entry → `HistoryScreen(controller, onExploreAudio: ...)`.
- No Episode Detail screen exists; episodes play + push `PodcastPlayerScreen` (same as search/library).

## Test conventions
- Helpers in each `test/*_test.dart`: `run<X>Test` pumps `MaterialApp(theme: buildAppTheme(), home: AppShell(controller))`, unmounts then disposes.
- `test/library_test.dart`: `switchToLibrary`, `libraryList()`, `revealInLibrary`, `inLibrary`/`libraryText`.
- `test/history_test.dart`: `openHistory` (switch to library → scroll to `library-history` → tap → pump 400ms), `inHistory`/`historyText`.

## Completed features
- Radio home/detail/player; Podcast home/detail/player; global search; Library; Downloads (entry + stub route only); Listening History; persistent podcast mini + per-screen radio mini; unified save/follow/download/history state; share via `share_plus` (`SharePlus.instance.share(ShareParams(...))`).
- **Sleep Timer** (global, both players): `SleepTimerMode { duration, endOfEpisode }` + `SleepTimerState` in `models/playback.dart`; owned by `PlaybackController` with an injectable `PlaybackController({DateTime Function()? clock})` so expiry is testable. Duration timers compare `endAt` vs the clock on a 1s `_sleepTicker`; END OF EPISODE fires from `_advance()` at episode end (full stop). `startSleepTimer(duration)` / `startSleepTimerEndOfEpisode()` / `cancelSleepTimer()`; `sleepActive`/`sleepMode`/`sleepRemaining`.
- UI: `SleepTimerSheet` bottom sheet (radio `showEndOfEpisode: false`, podcast true; keys `sleep-timer-15/30/45/60/-end/-off`) opened via `player-sleep` (radio) and `podcast-sleep` (podcast, previously a local no-op toggle); `SleepTimerIndicator` renders `Sleep · MM:SS` (key `sleep-countdown`) above NowPlayingInfo, recomputed on rebuild. Mini players show a subtle `bedtime_outlined` icon while a timer is active.
- On expiry, both players gate on `radioActive`/`podcastActive` and pop their own route once (`_exiting` post-frame `maybePop`) instead of crashing on `currentStation!`/`currentEpisode!`.
- Sleep timer persists through the sleep ticker's 1s notify regardless of player/screen; continues counting while paused; replacing a timer supersedes the old one; audio plays again after expiry.

## Verify commands
- `flutter analyze`
- `flutter test`
