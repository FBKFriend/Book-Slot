const _months = [
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

/// e.g. "Nov 16, 2026 · 2:05 PM"
String formatDateTime(DateTime d) {
  final t = d.toLocal();
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final mm = t.minute.toString().padLeft(2, '0');
  final ap = t.hour < 12 ? 'AM' : 'PM';
  return '${_months[t.month - 1]} ${t.day}, ${t.year} · $h12:$mm $ap';
}
