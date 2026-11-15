typedef DateBounds = ({DateTime? start, DateTime? endExclusive});

const Map<String, String> kDatePresetOptions = {
  'today': 'Today',
  'week': 'This week',
  'month': 'This month',
  'all': 'All time',
  'custom': 'Custom',
};

/// Turns a preset (or a custom From/To) into query bounds.
/// `start` is inclusive, `endExclusive` is the first moment AFTER the range.
DateBounds resolveRange(String preset, {DateTime? from, DateTime? to}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = DateTime(today.year, today.month, today.day + 1);

  switch (preset) {
    case 'today':
      return (start: today, endExclusive: tomorrow);
    case 'week':
      final monday = DateTime(
        today.year,
        today.month,
        today.day - (today.weekday - 1),
      );
      return (start: monday, endExclusive: tomorrow);
    case 'month':
      return (
        start: DateTime(today.year, today.month, 1),
        endExclusive: DateTime(today.year, today.month + 1, 1),
      );
    case 'custom':
      if (from == null || to == null) {
        return (start: null, endExclusive: null);
      }
      return (
        start: DateTime(from.year, from.month, from.day),
        endExclusive: DateTime(to.year, to.month, to.day + 1),
      );
    default:
      return (start: null, endExclusive: null);
  }
}
