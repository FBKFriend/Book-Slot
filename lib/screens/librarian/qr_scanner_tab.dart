import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/app_user.dart';
import '../../services/book_service.dart';
import '../../services/borrowing_service.dart';
import '../../services/qr_payload.dart';
import '../../services/qr_scan_service.dart';
import '../../services/reservation_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/book_cover.dart';

class QrScannerTab extends StatefulWidget {
  final AppUser user;
  final bool active; // true while this tab is the visible one
  const QrScannerTab({super.key, required this.user, required this.active});

  @override
  State<QrScannerTab> createState() => _QrScannerTabState();
}

class _QrScannerTabState extends State<QrScannerTab>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _appResumed = true;
  bool _busy = false; // a scan is being handled
  bool _running = false; // camera is on
  DateTime _ignoreUntil = DateTime(2000);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }

  @override
  void didUpdateWidget(covariant QrScannerTab old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// Camera runs only while this tab is visible, the app is in the
  /// foreground, and no scan is being handled.
  Future<void> _sync() async {
    final shouldRun = widget.active && _appResumed && !_busy;
    try {
      if (shouldRun && !_running) {
        _running = true;
        await _controller.start();
      } else if (!shouldRun && _running) {
        _running = false;
        await _controller.stop();
      }
    } catch (e) {
      _running = false;
      debugPrint('camera sync failed: $e');
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {}
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _alert(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _errorText(Object e) {
    if (e is BorrowLimitException) {
      return 'This student already has ${e.limit} books borrowed, which is the limit.';
    }
    if (e is PickupExpiredException) {
      return 'The pickup deadline has passed, so this reservation expired.';
    }
    if (e is ReservationChangedException) {
      return 'This reservation was already handled.';
    }
    if (e is NoFreeCopyException) {
      return 'No copy is available for this book.';
    }
    if (e is BookNotFoundException) {
      return 'This book no longer exists in the catalog.';
    }
    if (e is BorrowingChangedException) {
      return 'This book was already returned.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || DateTime.now().isBefore(_ignoreUntil)) return;

    String? raw;
    for (final b in capture.barcodes) {
      if (b.rawValue != null) {
        raw = b.rawValue;
        break;
      }
    }
    if (raw == null) return;

    final payload = QrPayload.parse(raw);
    if (payload == null) {
      _ignoreUntil = DateTime.now().add(const Duration(seconds: 2));
      _snack('That is not a BOOKSLOT QR code.');
      return;
    }

    _busy = true;
    await _sync(); // pauses the camera while we handle this scan
    try {
      await _process(payload);
    } catch (e) {
      debugPrint('scan failed: $e');
      if (mounted) {
        await _alert(
          'Scan failed',
          'Could not read this QR code. Please try again.',
        );
      }
    } finally {
      _ignoreUntil = DateTime.now().add(const Duration(seconds: 2));
      _busy = false;
      if (mounted) await _sync();
    }
  }

  Future<void> _process(QrPayload payload) async {
    final result = await QrScanService.instance.resolve(payload);
    if (!mounted) return;

    if (result.error != null) {
      if (result.deadlinePassed) {
        try {
          await ReservationService.instance.expireOverdue(
            actorRole: widget.user.role,
          );
        } catch (_) {}
      }
      if (!mounted) return;
      await _alert("Can't use this QR code", result.error!);
      return;
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ConfirmSheet(result: result),
    );
    if (ok != true || !mounted) return;

    final isPickup = result.kind == QrKind.pickup;
    try {
      if (isPickup) {
        await BorrowingService.instance.startBorrow(
          result.reservation!,
          staff: widget.user,
        );
        _snack('Pickup confirmed for ${result.reservation!.studentName}.');
      } else {
        await BorrowingService.instance.returnBook(
          result.borrowing!,
          staff: widget.user,
        );
        _snack('Return confirmed. The book is back in stock.');
      }
    } catch (e) {
      debugPrint('confirm failed: $e');
      if (e is PickupExpiredException) {
        try {
          await ReservationService.instance.expireOverdue(
            actorRole: widget.user.role,
          );
        } catch (_) {}
      }
      if (mounted) await _alert('Could not complete this', _errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner'),
        actions: [
          IconButton(
            tooltip: 'Flashlight',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(controller: _controller, onDetect: _onDetect),
          ),
          // Shown only when the camera could not start
          Positioned.fill(
            child: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, _) {
                if (state.error == null) return const SizedBox.shrink();
                return ColoredBox(
                  color: AppColors.background,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.no_photography_outlined,
                            size: 48,
                            color: AppColors.gold,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'The camera is not available. Check that BOOKSLOT has camera permission, then try again.',
                            textAlign: TextAlign.center,
                            style: t.bodyMedium,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              _running = false;
                              _sync();
                            },
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.gold, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(16),
              child: Text(
                "Point the camera at the student's pickup or return QR code",
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  final ScanResult result;
  const _ConfirmSheet({required this.result});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isPickup = result.kind == QrKind.pickup;
    final r = result.reservation!;
    final book = result.book;
    final due = result.borrowing?.dueAt;
    final overdue = result.borrowing?.isOverdue ?? false;
    final student = r.studentName.isEmpty ? r.studentEmail : r.studentName;
    final studentSub = [
      if ((r.studentId ?? '').isNotEmpty) r.studentId!,
      r.studentEmail,
    ].join('  ·  ');
    final accent = (!isPickup && overdue)
        ? const Color(0xFFE57373)
        : AppColors.gold;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPickup ? 'Confirm pickup' : 'Confirm return',
              style: t.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCover(
                  bookId: r.bookId,
                  version: book?.coverVersion ?? 0,
                  width: 72,
                  height: 108,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.bookTitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium?.copyWith(
                          color: AppColors.heading,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((book?.author ?? '').isNotEmpty)
                        Text(book!.author, style: t.bodyMedium),
                      const SizedBox(height: 2),
                      Text(r.bookId, style: t.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: AppColors.border, height: 28),
            Text('Student', style: t.bodySmall),
            const SizedBox(height: 2),
            Text(
              student,
              style: const TextStyle(
                color: AppColors.heading,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(studentSub, style: t.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isPickup
                      ? Icons.schedule
                      : (overdue
                            ? Icons.warning_amber_rounded
                            : Icons.event_outlined),
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isPickup
                        ? (r.pickupDeadline == null
                              ? 'Approved reservation'
                              : 'Pick up by ${formatDate(r.pickupDeadline!)}')
                        : (due == null
                              ? 'No due date'
                              : overdue
                              ? 'Overdue · was due ${formatDate(due)}'
                              : 'Due ${formatDate(due)}'),
                    style: TextStyle(color: accent, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isPickup ? 'Hand over the book shown above after you confirm.' : 'Make sure the book in your hands matches the one shown above.',
              style: t.bodySmall,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(isPickup ? 'Confirm pickup' : 'Confirm return'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
