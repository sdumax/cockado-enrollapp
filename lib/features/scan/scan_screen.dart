import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/widgets/mode_tabs.dart';
import 'scan_providers.dart';
import 'ticket_scan_screen.dart';
import 'face_capture_screen.dart';
import 'touch_screen.dart';
import 'tally_screen.dart';

export 'scan_providers.dart' show activeScanModeProvider, captureActiveProvider;

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  Timer? _inactivityTimer;
  static const _inactivityDuration = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _resetInactivityTimer();
    _restoreLastMode();
  }

  Future<void> _restoreLastMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('lastScanMode') ?? 'ticket';
    final mode = ScanMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ScanMode.ticket,
    );
    if (mounted) ref.read(activeScanModeProvider.notifier).state = mode;
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityDuration, () {
      if (!mounted) return;
      // Don't enter standby while a capture is actively in progress.
      if (ref.read(captureActiveProvider)) {
        _resetInactivityTimer();
        return;
      }
      // Don't enter standby while Settings or Enrolment is open on top.
      if (ref.read(standbyInhibitedProvider)) {
        _resetInactivityTimer();
        return;
      }
      context.go('/standby');
    });
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(activeScanModeProvider);
    return Listener(
      onPointerDown: (_) => _resetInactivityTimer(),
      child: IndexedStack(
        index: mode.index,
        children: const [
          TicketScanScreen(),
          FaceCaptureScreen(),
          TouchScreen(),
          TallyScreen(),
        ],
      ),
    );
  }
}
