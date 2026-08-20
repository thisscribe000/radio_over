# radio_over — Project Context & Build Log

Flutter audio app: radio + podcasts. In-memory state on `PlaybackController` (a plain `ChangeNotifier`), no persistence/backend/state-management library. Widget-test driven (`flutter test`), analyzer clean.

## Build status
- **110 tests pass, `flutter analyze` clean** (as of History screen completion).
- Radio + Podcast saving/history/downloads unified on `PlaybackController`.
- Library screen (third shell tab) and Listening History screen built and wired.

## Architecture rules
- `PlaybackController` is the single source of truth: `audioType`/`status`/`currentStation`/`currentEpisode`, shared stores `favouriteStations`, `savedShows`, `savedEpisodes`, `downloadedEpisodes`, `recentHistory` (bounded `List<ListenRecord>`), and `listeningHistory` (bounded `List<ListeningHistoryItem>`, cap `maxListeningHistoryEntries = 150`, deduped, references content by id).
- `ListenRecord` (models/playback.dart) embeds station/episode; `ListeningHistoryItem` stores `id/contentType/contentId/listenedAt/durationListened/playbackPosition` only.
- Timer rule in tests: unmount tree (`pumpWidget(SizedBox())`) before `controller.dispose()` or the 1s playback ticker trips `!timersPending`.
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

## IN-PROGRESS (unfinished prompt) — SLEEP TIMER
**Task:** global sleep timer for both Radio + Podcast players. NOT yet started (no code written).

Requirements to implement when resumed:
- Access from both Radio Player and Podcast Player via existing player action/menu system (no new permanent nav item).
- Options: 15/30/45/60 MINUTES; Podcasts additionally END OF EPISODE (radio: never shows it).
- Active timer shows subtly in player, e.g. `Sleep · 29:42`, countdown in real time via target/end timestamp recalculated on rebuild (not a continuously ticking UI counter). Cancel = `Turn Off Sleep Timer` (audio continues).
- On expiry: stop current audio (player + mini player + playback state update), no crash, play again works. Podcast END OF EPISODE stops at episode end, never auto-starts another.
- State centralized on `PlaybackController` (the existing state-management architecture), NOT in widgets. Concept: `SleepTimerState { active, mode (duration|endOfEpisode), remainingDuration, startedAt, endAt }`. No new state library.
- Persistence across screens (player/mini/library/search) required; across app launches NOT required.
- Edge cases: cancel before completion; pause/resume while active (countdown continues when paused — prefer standard sleep-timer behaviour); radio↔podcast switching; podcast ends before time expires; selecting a new timer replaces the active one.
- Mini player: timer continues running; subtle indication only if it fits the design system (not required to be prominent).
- Quiet/simple/premium/unobtrusive visual character. Do NOT build: notifications, alarms, schedules, profiles, new players, settings, backend.
- Suggested implementation: add sleep-timer state + a `Timer`/`DateTime`-based check on `PlaybackController`, `stop()` when elapsed; add menu entry + countdown text to both players; ensure tests cover pause/resume, cancel, replace, expiry, END OF EPISODE, radio excludes END OF EPISODE. Verify: `flutter analyze` + `flutter test`.

## Verify commands
- `flutter analyze`
- `flutter test`
