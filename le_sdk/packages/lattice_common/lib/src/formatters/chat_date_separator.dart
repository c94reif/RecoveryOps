const List<String> _kMonthAbbr = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// True if [a] and [b] fall on the same calendar day (local time).
bool isSameLocalDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Returns a chat date-separator label for [day], relative to [now].
///
/// `Today` / `Yesterday` for the current and previous calendar day,
/// otherwise an abbreviated absolute date like `Jun 23, 2026`.
/// [now] defaults to `DateTime.now()` and is injectable for tests.
String formatChatDateSeparator(DateTime day, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));
  if (isSameLocalDay(day, today)) return 'Today';
  if (isSameLocalDay(day, yesterday)) return 'Yesterday';
  return '${_kMonthAbbr[day.month - 1]} ${day.day}, ${day.year}';
}
