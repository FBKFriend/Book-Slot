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

/// e.g. "Nov 16, 2026"
String formatDate(DateTime d) {
  final t = d.toLocal();
  return '${_months[t.month - 1]} ${t.day}, ${t.year}';
}

/// e.g. 1500 -> "₱1,500"
String formatPeso(int amount) {
  final s = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${amount < 0 ? '-' : ''}₱$buf';
}
