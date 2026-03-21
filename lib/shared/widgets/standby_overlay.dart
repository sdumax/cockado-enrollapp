import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cockado_enrollapp/core/theme/app_colors.dart';

class StandbyOverlay extends StatelessWidget {
  const StandbyOverlay({
    super.key,
    required this.onWake,
    required this.version,
    this.dateTime,
  });

  final VoidCallback onWake;
  final String version;
  final DateTime? dateTime;

  @override
  Widget build(BuildContext context) {
    final now = dateTime ?? DateTime.now();
    final timeString = DateFormat('HH:mm').format(now);
    final dateString = _formatDate(now);

    return GestureDetector(
      onDoubleTap: onWake,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.standbyBackground,
        child: Column(
          children: [
            // Main content — slightly above center
            Expanded(
              child: Align(
                alignment: const Alignment(0.0, -0.25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Camera-off icon
                    const Icon(
                      Icons.videocam_off_outlined,
                      size: 28.0,
                      color: Color(0xFF1A2D45),
                    ),
                    const SizedBox(height: 20.0),
                    // Clock
                    Text(
                      timeString,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 60.0,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.0,
                        color: Color(0xFF2D5A8A),
                        decoration: TextDecoration.none,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    // Date
                    Text(
                      dateString,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.0,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.0,
                        color: Color(0xFF1E3551),
                        decoration: TextDecoration.none,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 44.0),
                    // Concentric ring indicator
                    const _ConcentricRings(),
                    const SizedBox(height: 20.0),
                    // Wake instruction
                    const Text(
                      'DOUBLE TAP TO WAKE',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
                        color: Color(0xFF3D5678),
                        decoration: TextDecoration.none,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    // Subtitle
                    const Text(
                      'Camera stream paused',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.0,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF1A2D45),
                        decoration: TextDecoration.none,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            _StandbyFooter(version: version),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final day = DateFormat('EEE').format(dt).toUpperCase();
    final dayNum = dt.day.toString().padLeft(2, '0');
    final month = DateFormat('MMM').format(dt).toUpperCase();
    final year = dt.year.toString();
    return '$day · $dayNum $month · $year';
  }
}

// ---------------------------------------------------------------------------
// Concentric rings widget
// ---------------------------------------------------------------------------

class _ConcentricRings extends StatelessWidget {
  const _ConcentricRings();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120.0,
      height: 120.0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(120.0, 120.0),
            painter: _RingsPainter(),
          ),
          const Text(
            '×2',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16.0,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2563EB),
              decoration: TextDecoration.none,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Outer ring — 120px diameter, 1px stroke
    final outerPaint = Paint()
      ..color = const Color(0xFF1E3A5F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, 60.0, outerPaint);

    // Middle ring — 80px diameter, 1px stroke
    final middlePaint = Paint()
      ..color = const Color(0x402563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, 40.0, middlePaint);

    // Inner filled circle — 48px diameter (24px radius)
    final centerFillPaint = Paint()
      ..color = const Color(0xFF0D1B2E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 24.0, centerFillPaint);

    // Inner circle border — 1.5px stroke
    final innerBorderPaint = Paint()
      ..color = const Color(0x702563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 24.0, innerBorderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Standby footer
// ---------------------------------------------------------------------------

class _StandbyFooter extends StatelessWidget {
  const _StandbyFooter({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    const footerColor = Color(0xFF1A2D45);

    return Container(
      height: 48.0,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'STANDBY · AUTO-CAPTURE PAUSED',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9.0,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: footerColor,
              decoration: TextDecoration.none,
              height: 1.0,
            ),
          ),
          Text(
            version.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 9.0,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
              color: footerColor,
              decoration: TextDecoration.none,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
