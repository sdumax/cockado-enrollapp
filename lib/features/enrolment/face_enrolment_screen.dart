import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cockado_enrollapp/core/theme/app_colors.dart';
import 'package:cockado_enrollapp/shared/widgets/app_status_bar.dart';
import 'package:cockado_enrollapp/shared/widgets/oval_viewfinder_widget.dart';
import 'package:cockado_enrollapp/shared/widgets/viewfinder_widget.dart';

enum _FaceEnrolState { idle, capturing, success, error }

class FaceEnrolmentScreen extends ConsumerStatefulWidget {
  const FaceEnrolmentScreen({
    super.key,
    required this.tally,
    this.nextScreen,
  });

  /// Tally number for the member being enrolled.
  final String tally;

  /// If set to 'fingerprint', navigates to fingerprint enrolment after success
  /// (used when BOTH enrolment type is selected).
  final String? nextScreen;

  @override
  ConsumerState<FaceEnrolmentScreen> createState() =>
      _FaceEnrolmentScreenState();
}

class _FaceEnrolmentScreenState extends ConsumerState<FaceEnrolmentScreen> {
  _FaceEnrolState _state = _FaceEnrolState.idle;
  Timer? _captureTimer;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _appVersion = 'v${info.version}+${info.buildNumber}');
  }

  void _onCapture() {
    if (_state != _FaceEnrolState.idle) return;
    setState(() => _state = _FaceEnrolState.capturing);

    // TODO: Initialize camera, run ML face detection + MobileFaceNet embedding,
    // save embedding to enrollees table keyed by tally number.
    _captureTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _state = _FaceEnrolState.success);
    });
  }

  void _onRetry() {
    _captureTimer?.cancel();
    setState(() => _state = _FaceEnrolState.idle);
  }

  void _onDone() {
    if (widget.nextScreen == 'fingerprint') {
      context.pushReplacement(
        '/enrolment/fingerprint?tally=${Uri.encodeComponent(widget.tally)}',
      );
    } else {
      context.go('/scan');
    }
  }

  ViewfinderState get _viewfinderState => switch (_state) {
        _FaceEnrolState.idle => ViewfinderState.idle,
        _FaceEnrolState.capturing => ViewfinderState.scanning,
        _FaceEnrolState.success => ViewfinderState.success,
        _FaceEnrolState.error => ViewfinderState.error,
      };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Column(
        children: [
          const AppStatusBar(),
          _buildHeader(),
          _buildCaptureArea(),
          _buildStatusArea(),
          _buildChipBar(),
          _buildCTABar(),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 64,
      color: AppColors.darkBackground,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFF152235),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'FACE ENROLMENT',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          _TallyBadge(tally: widget.tally),
        ],
      ),
    );
  }

  Widget _buildCaptureArea() {
    return Expanded(
      child: Center(
        child: OvalViewfinderWidget(state: _viewfinderState),
      ),
    );
  }

  Widget _buildStatusArea() {
    final (headline, sub, headlineColor) = switch (_state) {
      _FaceEnrolState.idle => (
          'POSITION FACE FOR ENROLMENT',
          'Look straight and hold still',
          AppColors.textPrimary,
        ),
      _FaceEnrolState.capturing => (
          'CAPTURING FACE DATA...',
          'Hold still, processing...',
          AppColors.textPrimary,
        ),
      _FaceEnrolState.success => (
          'FACE ENROLLED',
          'Biometric data saved successfully',
          AppColors.success,
        ),
      _FaceEnrolState.error => (
          'ENROLMENT FAILED',
          'Could not detect face clearly. Try again.',
          AppColors.error,
        ),
    };

    return SizedBox(
      height: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            headline,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: headlineColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChipBar() {
    final (icon, label, chipColor) = switch (_state) {
      _FaceEnrolState.idle || _FaceEnrolState.capturing => (
          Icons.camera_alt_outlined,
          'FACE ENROLMENT',
          AppColors.blue,
        ),
      _FaceEnrolState.success => (
          Icons.check_circle_outline,
          'ENROLMENT COMPLETE',
          AppColors.success,
        ),
      _FaceEnrolState.error => (
          Icons.refresh,
          'TRY AGAIN',
          AppColors.error,
        ),
    };

    return SizedBox(
      height: 64,
      child: Center(
        child: _StateChip(icon: icon, label: label, color: chipColor),
      ),
    );
  }

  Widget _buildCTABar() {
    return SizedBox(
      height: 84,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: switch (_state) {
          _FaceEnrolState.idle => _CTAButton(
              label: 'CAPTURE & ENROL',
              icon: Icons.camera_alt_outlined,
              color: AppColors.blue,
              onPressed: _onCapture,
            ),
          _FaceEnrolState.capturing => _CTAButton(
              label: 'CAPTURING...',
              isLoading: true,
              color: AppColors.darkSurface,
              onPressed: null,
            ),
          _FaceEnrolState.success => _CTAButton(
              label: 'DONE',
              icon: Icons.check_circle_outline,
              color: AppColors.success,
              onPressed: _onDone,
            ),
          _FaceEnrolState.error => _CTAButton(
              label: 'RETRY ENROLMENT',
              icon: Icons.refresh,
              color: AppColors.error,
              onPressed: _onRetry,
            ),
        },
      ),
    );
  }

  Widget _buildFooter() {
    return _EnrolmentFooter(version: _appVersion);
  }
}

// ---------------------------------------------------------------------------
// Fingerprint enrolment screen
// ---------------------------------------------------------------------------

enum _FpEnrolState { idle, reading, success, error }

class FingerprintEnrolmentScreen extends ConsumerStatefulWidget {
  const FingerprintEnrolmentScreen({
    super.key,
    required this.tally,
  });

  final String tally;

  @override
  ConsumerState<FingerprintEnrolmentScreen> createState() =>
      _FingerprintEnrolmentScreenState();
}

class _FingerprintEnrolmentScreenState
    extends ConsumerState<FingerprintEnrolmentScreen>
    with SingleTickerProviderStateMixin {
  _FpEnrolState _state = _FpEnrolState.idle;
  Timer? _readTimer;
  String _appVersion = '';

  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _glowController.reverse();
        } else if (status == AnimationStatus.dismissed &&
            _state == _FpEnrolState.reading) {
          _glowController.forward();
        }
      });

    _glowAnimation = Tween<double>(begin: 0.15, end: 0.55).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _loadVersion();
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _appVersion = 'v${info.version}+${info.buildNumber}');
  }

  void _onStartReading() {
    if (_state != _FpEnrolState.idle) return;
    setState(() => _state = _FpEnrolState.reading);
    _glowController.forward();

    // TODO: Call fingerprint reader enrolment API to capture and store template.
    _readTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _glowController.stop();
      _glowController.reset();
      setState(() => _state = _FpEnrolState.success);
    });
  }

  void _onRetry() {
    _readTimer?.cancel();
    _glowController.stop();
    _glowController.reset();
    setState(() => _state = _FpEnrolState.idle);
  }

  void _onDone() => context.go('/scan');

  Color get _stateColor => switch (_state) {
        _FpEnrolState.idle => AppColors.blue,
        _FpEnrolState.reading => AppColors.blue,
        _FpEnrolState.success => AppColors.success,
        _FpEnrolState.error => AppColors.error,
      };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Column(
        children: [
          const AppStatusBar(),
          _buildHeader(),
          _buildReaderArea(),
          _buildStatusArea(),
          _buildChipBar(),
          _buildCTABar(),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 64,
      color: AppColors.darkBackground,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFF152235),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'FINGERPRINT ENROLMENT',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          _TallyBadge(tally: widget.tally),
        ],
      ),
    );
  }

  Widget _buildReaderArea() {
    return Expanded(
      child: Center(
        child: _ReaderCard(
          state: _state,
          stateColor: _stateColor,
          glowAnimation: _glowAnimation,
        ),
      ),
    );
  }

  Widget _buildStatusArea() {
    final (headline, sub, headlineColor) = switch (_state) {
      _FpEnrolState.idle => (
          'PLACE FINGER ON READER',
          'Touch the reader and hold still',
          AppColors.textPrimary,
        ),
      _FpEnrolState.reading => (
          'READING FINGERPRINT...',
          'Hold your finger steady on the reader',
          AppColors.textPrimary,
        ),
      _FpEnrolState.success => (
          'FINGERPRINT ENROLLED',
          'Biometric data saved successfully',
          AppColors.success,
        ),
      _FpEnrolState.error => (
          'ENROLMENT FAILED',
          'Fingerprint not recognised. Try again.',
          AppColors.error,
        ),
    };

    return SizedBox(
      height: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            headline,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: headlineColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChipBar() {
    final (icon, label, chipColor) = switch (_state) {
      _FpEnrolState.idle || _FpEnrolState.reading => (
          Icons.fingerprint,
          'FINGERPRINT ENROLMENT',
          AppColors.blue,
        ),
      _FpEnrolState.success => (
          Icons.check_circle_outline,
          'FINGERPRINT ENROLMENT',
          AppColors.success,
        ),
      _FpEnrolState.error => (
          Icons.fingerprint,
          'FINGERPRINT ENROLMENT',
          AppColors.error,
        ),
    };

    return SizedBox(
      height: 64,
      child: Center(
        child: _StateChip(icon: icon, label: label, color: chipColor),
      ),
    );
  }

  Widget _buildCTABar() {
    return SizedBox(
      height: 84,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: switch (_state) {
          _FpEnrolState.idle => _CTAButton(
              label: 'READY TO SCAN',
              icon: Icons.swap_horiz,
              color: AppColors.blue,
              onPressed: _onStartReading,
            ),
          _FpEnrolState.reading => _CTAButton(
              label: 'READING...',
              isLoading: true,
              color: AppColors.darkSurface,
              onPressed: null,
            ),
          _FpEnrolState.success => _CTAButton(
              label: 'DONE',
              icon: Icons.check_circle_outline,
              color: AppColors.success,
              onPressed: _onDone,
            ),
          _FpEnrolState.error => _CTAButton(
              label: 'RETRY ENROLMENT',
              icon: Icons.refresh,
              color: AppColors.error,
              onPressed: _onRetry,
            ),
        },
      ),
    );
  }

  Widget _buildFooter() => _EnrolmentFooter(version: _appVersion);
}

// ---------------------------------------------------------------------------
// Reader card widget
// ---------------------------------------------------------------------------

class _ReaderCard extends StatelessWidget {
  const _ReaderCard({
    required this.state,
    required this.stateColor,
    required this.glowAnimation,
  });

  final _FpEnrolState state;
  final Color stateColor;
  final Animation<double> glowAnimation;

  IconData get _icon => switch (state) {
        _FpEnrolState.idle || _FpEnrolState.reading => Icons.fingerprint,
        _FpEnrolState.success => Icons.check_circle_outline,
        _FpEnrolState.error => Icons.cancel_outlined,
      };

  Color get _ledColor => switch (state) {
        _FpEnrolState.idle => AppColors.blue.withValues(alpha: 0.5),
        _FpEnrolState.reading => AppColors.blue,
        _FpEnrolState.success => AppColors.success,
        _FpEnrolState.error => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: glowAnimation,
          builder: (context, child) {
            final glowOpacity = state == _FpEnrolState.reading
                ? glowAnimation.value
                : (state == _FpEnrolState.idle ? 0.15 : 0.30);

            return Container(
              width: 264,
              height: 134,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: stateColor.withValues(alpha: glowOpacity),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 240,
              height: 118,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: stateColor.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Stack(
                children: [
                  // LED dot top-right
                  Positioned(
                    top: 12,
                    right: 14,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _ledColor,
                        boxShadow: [
                          BoxShadow(
                            color: stateColor.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Fingerprint / state icon centered
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        _icon,
                        key: ValueKey(state),
                        size: 48,
                        color: stateColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'BIOMETRIC READER',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: AppColors.textMuted.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

class _TallyBadge extends StatelessWidget {
  const _TallyBadge({required this.tally});
  final String tally;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.blue.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Text(
        '# $tally',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppColors.blue,
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        color: color.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CTAButton extends StatelessWidget {
  const _CTAButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.darkSurface,
      disabledForegroundColor: AppColors.textMuted,
      elevation: 0,
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );

    if (isLoading) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        label: Text(label),
        style: style,
      );
    }

    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: style,
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: style,
      child: Text(label),
    );
  }
}

class _EnrolmentFooter extends StatelessWidget {
  const _EnrolmentFooter({required this.version});
  final String version;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.darkBackground,
        border: Border(
          top: BorderSide(color: AppColors.darkDivider, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'ENROLMENT MODE',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: AppColors.textMuted,
            ),
          ),
          Text(
            version.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
