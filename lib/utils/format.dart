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