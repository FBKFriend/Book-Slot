enum QrKind { pickup, returning }

/// What a BOOKSLOT QR code says. It only holds a reservation id,
/// never any personal info.
class QrPayload {
  final QrKind kind;
  final String reservationId;
  const QrPayload(this.kind, this.reservationId);

  static const _prefix = 'bookslot';

  static String pickup(String reservationId) =>
      '$_prefix:pickup:$reservationId';

  static String returning(String reservationId) =>
      '$_prefix:return:$reservationId';

  /// Returns null when the text is not a BOOKSLOT code.
  static QrPayload? parse(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length != 3 || parts[0] != _prefix) return null;
    final id = parts[2];
    if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id)) return null;
    switch (parts[1]) {
      case 'pickup':
        return QrPayload(QrKind.pickup, id);
      case 'return':
        return QrPayload(QrKind.returning, id);
      default:
        return null;
    }
  }
}
