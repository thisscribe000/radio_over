/// Formats a [Duration] as a compact clock string.
///
/// Examples:
///   - 32 minutes  -> "32:00"
///   - 1 hour 2 min -> "1:02:00"
///   - 30 seconds  -> "0:30"
String formatDuration(Duration duration) {
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes % 60;
  final int seconds = duration.inSeconds % 60;
  final String minutesPadded = minutes.toString().padLeft(2, '0');
  final String secondsPadded = seconds.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$minutesPadded:$secondsPadded';
  return '$minutes:$secondsPadded';
}

/// Formats when a listen started for the library's RECENTLY PLAYED rows.
///
/// Examples:
///   - earlier today   -> "TODAY · 14:20"
///   - yesterday       -> "YESTERDAY · 18:20"
///   - older           -> "AUG 16"
String formatListenedAt(DateTime at) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime day = DateTime(at.year, at.month, at.day);
  final int days = today.difference(day).inDays;
  final String time = '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
  if (days == 0) return 'TODAY · $time';
  if (days == 1) return 'YESTERDAY · $time';
  const List<String> months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  return '${months[at.month - 1]} ${at.day}';
}

/// Formats when a podcast feed was last refreshed, for the quiet
/// "UPDATED …" metadata line on the show screen.
///
/// Examples (against [now], defaulting to the real clock):
///   - under a minute -> "UPDATED JUST NOW"
///   - 4 minutes      -> "UPDATED 4M AGO"
///   - 3 hours        -> "UPDATED 3H AGO"
///   - 6 days         -> "UPDATED 6D AGO"
///   - older          -> "AUG 12"
String formatUpdatedAgo(DateTime at, {DateTime? now}) {
  final DateTime reference = now ?? DateTime.now();
  final Duration age = reference.difference(at);
  if (age.inMinutes < 1) return 'UPDATED JUST NOW';
  if (age.inMinutes < 60) return 'UPDATED ${age.inMinutes}M AGO';
  if (age.inHours < 24) return 'UPDATED ${age.inHours}H AGO';
  if (age.inDays < 7) return 'UPDATED ${age.inDays}D AGO';
  const List<String> months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  return '${months[at.month - 1]} ${at.day}';
}