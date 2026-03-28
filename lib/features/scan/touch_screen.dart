import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:drift/drift.dart' show Value;
import 'package:cockado_enrollapp/core/theme/app_colors.dart';
import 'package:cockado_enrollapp/core/db/database_provider.dart';
import 'package:cockado_enrollapp/core/db/app_database.dart';
import 'package:cockado_enrollapp/core/services/device_id_service.dart';
import 'package:cockado_enrollapp/core/services/fingerprint_reader_service.dart';
import 'package:cockado_enrollapp/features/init/sync_status_repository.dart';
import '../../shared/widgets/app_status_bar.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/mode_tabs.dart';
import '../../shared/widgets/footer_bar.dart';
import '../../shared/widgets/capture_toast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'scan_providers.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class TouchScreen extends ConsumerStatefulWidget {
  const TouchScreen({super.key});

  @override
  ConsumerState<TouchScreen> createState() => _TouchScreenState();
}

class _TouchScreenState extends ConsumerState<TouchScreen>
    with SingleTickerProviderStateMixin {
  // ── Services ──────────────────────────────────────────────────────────────
  late final FingerprintReaderService _reader;
  StreamSubscription<FingerprintReaderState>? _stateSub;
  StreamSubscription<FingerprintReadResult>? _resultSub;

  // ── UI state ──────────────────────────────────────────────────────────────
  FingerprintReaderState _readerState = FingerprintReaderState.idle;
  String? _confirmedName;
  bool _showToast = false;
  ToastType _toastType = ToastType.success;
  String _toastTitle = '';
  String? _toastSubtitle;

  // ── Animation (glow pulse while reading) ─────────────────────────────────
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  // ── App meta ──────────────────────────────────────────────────────────────
  String _version = '';

  // Debounce timer for delayed stream start after mode switch
  Timer? _streamStartTimer;
  static const _streamStartDelay = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _glowController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          if (_readerState == FingerprintReaderState.reading) {
            _glowController.forward();
          }
        }
      });

    _glowAnimation = Tween<double>(begin: 0.15, end: 0.55).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _reader = ref.read(fingerprintReaderServiceProvider);

    _stateSub = _reader.stateStream.listen(_onReaderStateChanged);
    _resultSub = _reader.resultStream.listen(_onResult);

    _loadMeta();

    if (_reader.isConnected) {
      _reader.startReading();
    }
  }

  @override
  void dispose() {
    _stopStreaming();
    _streamStartTimer?.cancel();
    _stateSub?.cancel();
    _resultSub?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  // ── Streaming control ─────────────────────────────────────────────────────

  void _stopStreaming() {
    if (_reader.isConnected) _reader.stopReading();
  }

  void _startStreaming() {
    if (_reader.isConnected) _reader.startReading();
  }

  // ── Meta ──────────────────────────────────────────────────────────────────

  Future<void> _loadMeta() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _version = 'v${info.version}+${info.buildNumber}';
    });
  }

  // ── Reader callbacks ──────────────────────────────────────────────────────

  void _onReaderStateChanged(FingerprintReaderState state) {
    if (!mounted) return;
    // Update capture-active flag so standby timer is aware.
    final isActive = state == FingerprintReaderState.reading ||
        state == FingerprintReaderState.success;
    ref.read(captureActiveProvider.notifier).state = isActive;
    setState(() {
      _readerState = state;
      if (state == FingerprintReaderState.reading) {
        _glowController.forward();
      } else {
        _glowController.stop();
        _glowController.reset();
      }
      if (state != FingerprintReaderState.success) {
        _confirmedName = null;
      }
    });
  }

  Future<void> _onResult(FingerprintReadResult result) async {
    if (!mounted) return;

    if (result.enrolleeId != null) {
      await _handleSuccess(result.enrolleeId!);
    } else {
      _showErrorToast(result.errorMessage ?? 'Fingerprint not recognised');
    }
  }

  Future<void> _handleSuccess(String enrolleeId) async {
    final db = ref.read(databaseProvider);
    final syncRepo = ref.read(syncStatusRepositoryProvider);
    final deviceIdResult = await ref.read(deviceIdProvider.future);

    final eventId = await syncRepo.getActiveEventId();
    if (eventId == null) {
      _showErrorToast('No active event configured');
      return;
    }

    final alreadyCheckedIn =
        await db.checkinsDao.hasCheckinForEvent(enrolleeId, eventId);
    if (alreadyCheckedIn) {
      _showErrorToast('Already checked in for this event');
      // Restart reading after a brief pause.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _reader.isConnected) _reader.startReading();
      });
      return;
    }

    await db.checkinsDao.insertCheckin(
      CheckinsCompanion(
        enrolleeId: Value(enrolleeId),
        eventId: Value(eventId),
        method: const Value('TOUCH'),
        deviceId: Value(deviceIdResult),
        timestamp: Value(DateTime.now()),
        syncStatus: const Value('PENDING'),
      ),
    );

    // Resolve display name.
    final enrollee = await db.enrolleesDao.getById(enrolleeId);
    final name = enrollee?.fullName ?? enrolleeId;

    if (!mounted) return;
    setState(() {
      _confirmedName = name;
    });

    _showSuccessToast(name);

    // Restart reading after showing success for 2 s.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _reader.isConnected) _reader.startReading();
    });
  }

  // ── Toast helpers ─────────────────────────────────────────────────────────

  void _showSuccessToast(String name) {
    setState(() {
      _showToast = true;
      _toastType = ToastType.success;
      _toastTitle = 'Identity Confirmed';
      _toastSubtitle = name;
    });
  }

  void _showErrorToast(String message) {
    setState(() {
      _showToast = true;
      _toastType = ToastType.error;
      _toastTitle = 'Not Recognised';
      _toastSubtitle = message;
    });
  }

  void _dismissToast() {
    if (!mounted) return;
    setState(() => _showToast = false);
  }

  // ── Mode tab handler ──────────────────────────────────────────────────────

  void _onModeChanged(ScanMode mode) async {
    ref.read(activeScanModeProvider.notifier).state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastScanMode', mode.name);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<ScanMode>(activeScanModeProvider, (prev, next) {
      if (next != ScanMode.touch) {
        _streamStartTimer?.cancel();
        _stopStreaming();
      } else if (prev != ScanMode.touch) {
        _streamStartTimer?.cancel();
        _streamStartTimer = Timer(_streamStartDelay, () {
          if (mounted && ref.read(activeScanModeProvider) == ScanMode.touch) {
            _startStreaming();
          }
        });
      }
    });

    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          Column(
            children: [
              const AppStatusBar(),
              AppHeader(
                title: 'COC-CHECKIN',
                trailing: GestureDetector(
                  onTap: () async {
                    _stopStreaming();
                    await context.push('/settings');
                    if (mounted &&
                        ref.read(activeScanModeProvider) == ScanMode.touch) {
                      _startStreaming();
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 32.0,
                    height: 32.0,
                    decoration: const BoxDecoration(
                      color: AppColors.darkCard,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      size: 16.0,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              // ── Middle content area ──────────────────────────────────────
              Expanded(
                child: isTablet
                    ? _ReaderContent(
                        readerState: _readerState,
                        isConnected: _reader.isConnected,
                        confirmedName: _confirmedName,
                        glowAnimation: _glowAnimation,
                      )
                    : const _TabletOnlyNotice(),
              ),
              // ── Status row ───────────────────────────────────────────────
              _StatusRow(
                readerState: _readerState,
                isConnected: _reader.isConnected,
              ),
              // ── Mode tabs ────────────────────────────────────────────────
              ModeTabs(
                activeMode: ScanMode.touch,
                onModeChanged: _onModeChanged,
                touchEnabled: isTablet,
              ),
              // ── New Enrolment button ─────────────────────────────────────
              _NewEnrolmentButton(
                onTap: () => context.push('/enrolment'),
              ),
              // ── Footer ───────────────────────────────────────────────────
              FooterBar(version: _version),
            ],
          ),

          // ── Toast overlay ────────────────────────────────────────────────
          if (_showToast)
            Positioned(
              top: 62.0 + 64.0 + 12.0, // below status bar + header
              left: 0.0,
              right: 0.0,
              child: CaptureToast(
                type: _toastType,
                title: _toastTitle,
                subtitle: _toastSubtitle,
                onDismiss: _dismissToast,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reader content (tablet only)
// ---------------------------------------------------------------------------

class _ReaderContent extends StatelessWidget {
  const _ReaderContent({
    required this.readerState,
    required this.isConnected,
    required this.confirmedName,
    required this.glowAnimation,
  });

  final FingerprintReaderState readerState;
  final bool isConnected;
  final String? confirmedName;
  final Animation<double> glowAnimation;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _BiometricCard(
        readerState: readerState,
        isConnected: isConnected,
        confirmedName: confirmedName,
        glowAnimation: glowAnimation,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Biometric reader card
// ---------------------------------------------------------------------------

class _BiometricCard extends StatelessWidget {
  const _BiometricCard({
    required this.readerState,
    required this.isConnected,
    required this.confirmedName,
    required this.glowAnimation,
  });

  final FingerprintReaderState readerState;
  final bool isConnected;
  final String? confirmedName;
  final Animation<double> glowAnimation;

  Color get _stateColor {
    if (!isConnected) return AppColors.darkDivider;
    switch (readerState) {
      case FingerprintReaderState.idle:
        return AppColors.blue;
      case FingerprintReaderState.reading:
        return AppColors.blue;
      case FingerprintReaderState.success:
        return AppColors.success;
      case FingerprintReaderState.error:
        return AppColors.error;
    }
  }

  String get _stateLabel {
    if (!isConnected) return 'CONNECT READER';
    switch (readerState) {
      case FingerprintReaderState.idle:
        return 'WAITING FOR FINGER';
      case FingerprintReaderState.reading:
        return 'READING...';
      case FingerprintReaderState.success:
        return 'IDENTITY CONFIRMED';
      case FingerprintReaderState.error:
        return 'NOT RECOGNISED';
    }
  }

  String? get _subText {
    if (!isConnected) {
      return 'Please attach the external\nbiometric reader device';
    }
    switch (readerState) {
      case FingerprintReaderState.idle:
        return 'Place your finger on the reader';
      case FingerprintReaderState.reading:
        return 'Hold still…';
      case FingerprintReaderState.success:
        return confirmedName;
      case FingerprintReaderState.error:
        return 'Please try again';
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateColor = _stateColor;

    return Container(
      width: 280.0,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── LED indicator + label row ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'BIOMETRIC READER',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
              // LED dot
              Container(
                width: 10.0,
                height: 10.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isConnected ? AppColors.success : AppColors.darkDivider,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28.0),

          // ── Glow ring + fingerprint icon ───────────────────────────────
          AnimatedBuilder(
            animation: glowAnimation,
            builder: (context, child) {
              final glowOpacity = readerState == FingerprintReaderState.reading
                  ? glowAnimation.value
                  : 0.3;

              return Container(
                width: 120.0,
                height: 120.0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(60.0),
                  border: Border.all(
                    color: stateColor,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: stateColor.withValues(alpha: glowOpacity),
                      blurRadius: 20.0,
                      spreadRadius: 0.0,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Center(
              child: Icon(
                Icons.fingerprint,
                size: 64.0,
                color: _stateColor,
              ),
            ),
          ),

          const SizedBox(height: 24.0),

          // ── State label ────────────────────────────────────────────────
          Text(
            _stateLabel,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.0,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: stateColor,
            ),
          ),

          // ── Sub text ───────────────────────────────────────────────────
          if (_subText != null && _subText!.isNotEmpty) ...[
            const SizedBox(height: 8.0),
            Text(
              _subText!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.0,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tablet-only notice (shown on phones)
// ---------------------------------------------------------------------------

class _TabletOnlyNotice extends StatelessWidget {
  const _TabletOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.0,
              height: 72.0,
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(36.0),
                border: Border.all(
                  color: AppColors.darkDivider,
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.tablet_android_outlined,
                size: 36.0,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20.0),
            const Text(
              'TABLET ONLY',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.0,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8.0),
            const Text(
              'The external biometric reader\nrequires a tablet device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.0,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status row (80 px)
// ---------------------------------------------------------------------------

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.readerState,
    required this.isConnected,
  });

  final FingerprintReaderState readerState;
  final bool isConnected;

  String get _statusText {
    if (!isConnected) return 'READER DISCONNECTED';
    switch (readerState) {
      case FingerprintReaderState.idle:
        return 'READER READY';
      case FingerprintReaderState.reading:
        return 'SCANNING';
      case FingerprintReaderState.success:
        return 'CHECK-IN COMPLETE';
      case FingerprintReaderState.error:
        return 'SCAN FAILED';
    }
  }

  Color get _statusColor {
    if (!isConnected) return AppColors.textMuted;
    switch (readerState) {
      case FingerprintReaderState.idle:
        return AppColors.textSecondary;
      case FingerprintReaderState.reading:
        return AppColors.blue;
      case FingerprintReaderState.success:
        return AppColors.success;
      case FingerprintReaderState.error:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80.0,
      decoration: const BoxDecoration(
        color: AppColors.darkBackground,
        border: Border(
          top: BorderSide(color: AppColors.darkDivider, width: 1.0),
          bottom: BorderSide(color: AppColors.darkDivider, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          Container(
            width: 8.0,
            height: 8.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _statusColor,
            ),
          ),
          const SizedBox(width: 12.0),
          Text(
            _statusText,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.0,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: _statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// New Enrolment button (84 px)
// ---------------------------------------------------------------------------

class _NewEnrolmentButton extends StatelessWidget {
  const _NewEnrolmentButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 84.0,
        width: double.infinity,
        color: AppColors.darkBackground,
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: AppColors.darkDivider,
              width: 1.0,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_add_outlined,
                size: 16.0,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 10.0),
              Text(
                'NEW ENROLMENT',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
