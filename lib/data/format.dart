const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String monthShort(DateTime d) => _months[d.month - 1];
String weekdayShort(DateTime d) => _days[d.weekday - 1];

String clock(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "9:40 AM", "Yesterday", "Mon", "12 Nov" or "12 Nov 2025".
String relativeDay(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return clock(d);
  if (diff == 1) return 'Yesterday';
  if (diff < 7 && diff > 0) return weekdayShort(d);
  if (d.year == n.year) return '${d.day} ${monthShort(d)}';
  return '${d.day} ${monthShort(d)} ${d.year}';
}

/// Header line such as "WED · 13 NOV".
String headerDate(DateTime d) => '${weekdayShort(d).toUpperCase()} · ${d.day} ${monthShort(d).toUpperCase()}';

String twoDigits(int v) => v.toString().padLeft(2, '0');
