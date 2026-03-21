import 'package:flutter/material.dart';
import 'package:cockado_enrollapp/core/theme/app_colors.dart';

enum ViewfinderState { idle, scanning, success, error }

class ViewfinderWidget extends StatefulWidget {
  final ViewfinderState state;
  final String? successName;

  const ViewfinderWidget({
    super.key,
    required this.state,
    this.successName,
  });

  @override
  State<ViewfinderWidget> createState() => _ViewfinderWidgetState();
}

class _ViewfinderWidgetState extends State<ViewfinderWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scanLineAnim;

  static const double _viewfinderWidth = 280.0;
  static const double _viewfinderHeight = 340.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _scanLineAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(ViewfinderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.state == ViewfinderState.scanning) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _bracketColor(ViewfinderState s) => switch (s) {
        ViewfinderState.idle => AppColors.blue,
        ViewfinderState.scanning => AppColors.blue,
        ViewfinderState.success => AppColors.success,
        ViewfinderState.error => AppColors.error,
      };

  Color _stateColor(ViewfinderState s) => switch (s) {
        ViewfinderState.idle => Colors.transparent,
        ViewfinderState.scanning => Colors.transparent,
        ViewfinderState.success => AppColors.success,
        ViewfinderState.error => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    final bracketColor = _bracketColor(widget.state);
    final overlayColor = _stateColor(widget.state);
    final showOverlay = widget.state == ViewfinderState.success ||
        widget.state == ViewfinderState.error;
    final showIcon = widget.state == ViewfinderState.success ||
        widget.state == ViewfinderState.error;
    final showScanLine = widget.state == ViewfinderState.idle ||
        widget.state == ViewfinderState.scanning;

    return Center(
      child: SizedBox(
        width: _viewfinderWidth,
        height: _viewfinderHeight,
        child: Stack(
          children: [
            // Corner brackets via CustomPainter
            Positioned.fill(
              child: CustomPaint(
                painter: _CornerBracketPainter(color: bracketColor),
              ),
            ),

            // State color overlay (success / error)
            if (showOverlay)
              Positioned.fill(
                child: Container(
                  color: overlayColor.withValues(alpha: 0.08),
                ),
              ),

            // Animated scan line
            if (showScanLine)
              _ScanLineLayer(
                animation: _scanLineAnim,
                state: widget.state,
                stateColor: bracketColor,
                viewfinderHeight: _viewfinderHeight,
              ),

            // Center icon for SUCCESS / ERROR
            if (showIcon)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.state == ViewfinderState.success
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      size: 48.0,
                      color: overlayColor,
                    ),
                    if (widget.state == ViewfinderState.success &&
                        widget.successName != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        widget.successName!,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

            // Label at the bottom
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: _StateLabel(state: widget.state),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scan line layer
// ---------------------------------------------------------------------------

class _ScanLineLayer extends StatelessWidget {
  final Animation<double> animation;
  final ViewfinderState state;
  final Color stateColor;
  final double viewfinderHeight;

  const _ScanLineLayer({
    required this.animation,
    required this.state,
    required this.stateColor,
    required this.viewfinderHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (state == ViewfinderState.idle) {
      // Static scan line near bottom
      return Positioned(
        left: 0,
        right: 0,
        top: viewfinderHeight * 0.80,
        child: _scanLineDecoration(stateColor, opacity: 0.3),
      );
    }

    // Scanning: animate top→bottom
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final topOffset = animation.value * (viewfinderHeight - 4);
        return Positioned(
          left: 0,
          right: 0,
          top: topOffset,
          child: _scanLineDecoration(stateColor, opacity: 1.0),
        );
      },
    );
  }

  Widget _scanLineDecoration(Color color, {required double opacity}) {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            color.withValues(alpha: opacity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// State label
// ---------------------------------------------------------------------------

class _StateLabel extends StatelessWidget {
  final ViewfinderState state;
  const _StateLabel({required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      ViewfinderState.idle => ('READY TO SCAN', AppColors.textSecondary),
      ViewfinderState.scanning => ('SCANNING...', AppColors.blueLight),
      ViewfinderState.success => ('SCAN COMPLETE', AppColors.success),
      ViewfinderState.error => ('SCAN FAILED', AppColors.error),
    };

    return Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Corner bracket painter
// ---------------------------------------------------------------------------

class _CornerBracketPainter extends CustomPainter {
  final Color color;
  static const double bracketLength = 24.0;
  static const double bracketThickness = 3.0;
  static const double cornerRadius = 2.0;

  const _CornerBracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = bracketThickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final l = bracketLength;

    // Top-left
    canvas.drawLine(Offset(0, l), Offset(0, cornerRadius), paint);
    canvas.drawLine(Offset(cornerRadius, 0), Offset(l, 0), paint);

    // Top-right
    canvas.drawLine(Offset(w - l, 0), Offset(w - cornerRadius, 0), paint);
    canvas.drawLine(Offset(w, cornerRadius), Offset(w, l), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, h - l), Offset(0, h - cornerRadius), paint);
    canvas.drawLine(Offset(cornerRadius, h), Offset(l, h), paint);

    // Bottom-right
    canvas.drawLine(Offset(w - l, h), Offset(w - cornerRadius, h), paint);
    canvas.drawLine(Offset(w, h - l), Offset(w, h - cornerRadius), paint);
  }

  @override
  bool shouldRepaint(_CornerBracketPainter oldDelegate) =>
      oldDelegate.color != color;
}
