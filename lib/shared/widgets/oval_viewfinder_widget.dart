import 'package:flutter/material.dart';
import 'package:cockado_enrollapp/core/theme/app_colors.dart';
import 'viewfinder_widget.dart';

/// Face-capture oval viewfinder — same states as [ViewfinderWidget].
class OvalViewfinderWidget extends StatefulWidget {
  const OvalViewfinderWidget({
    super.key,
    required this.state,
    this.successName,
  });

  final ViewfinderState state;

  /// Optional name shown below the checkmark on success.
  final String? successName;

  @override
  State<OvalViewfinderWidget> createState() => _OvalViewfinderWidgetState();
}

class _OvalViewfinderWidgetState extends State<OvalViewfinderWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;
  late final Animation<double> _scanAnimation;

  static const double _ovalW = 240;
  static const double _ovalH = 300;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _scanAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.linear),
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(OvalViewfinderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _updateAnimation();
  }

  void _updateAnimation() {
    if (widget.state == ViewfinderState.scanning) {
      _scanController.repeat();
    } else {
      _scanController.stop();
      _scanController.reset();
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Color get _stateColor => switch (widget.state) {
        ViewfinderState.idle => AppColors.blue,
        ViewfinderState.scanning => AppColors.blue,
        ViewfinderState.success => AppColors.success,
        ViewfinderState.error => AppColors.error,
      };

  double get _glowOpacity => switch (widget.state) {
        ViewfinderState.idle => 0.18,
        ViewfinderState.scanning => 0.35,
        ViewfinderState.success => 0.35,
        ViewfinderState.error => 0.35,
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _ovalW,
      height: _ovalH + 40, // extra room for success name
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _ovalW,
            height: _ovalH,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow shadow
                Container(
                  width: _ovalW,
                  height: _ovalH,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(
                      Radius.elliptical(_ovalW / 2, _ovalH / 2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _stateColor.withValues(alpha: _glowOpacity),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),

                // Oval clip with state color overlay + scan line
                ClipOval(
                  child: SizedBox(
                    width: _ovalW,
                    height: _ovalH,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Color overlay
                        if (widget.state == ViewfinderState.success ||
                            widget.state == ViewfinderState.error)
                          Container(
                            color: _stateColor.withValues(alpha: 0.08),
                          ),

                        // Animated scan line (scanning state only)
                        if (widget.state == ViewfinderState.scanning)
                          AnimatedBuilder(
                            animation: _scanAnimation,
                            builder: (_, __) => Positioned(
                              top: _scanAnimation.value * _ovalH,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.blue.withValues(alpha: 0),
                                      AppColors.blue,
                                      AppColors.blue.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Oval border ring
                Container(
                  width: _ovalW,
                  height: _ovalH,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(
                      Radius.elliptical(_ovalW / 2, _ovalH / 2),
                    ),
                    border: Border.all(color: _stateColor, width: 2.5),
                  ),
                ),

                // Person silhouette (hidden on ERROR)
                if (widget.state != ViewfinderState.error)
                  Icon(
                    Icons.person_outline,
                    size: 80,
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                  ),

                // State icon — success or error
                if (widget.state == ViewfinderState.success)
                  Icon(Icons.check_circle_outline,
                      size: 48, color: AppColors.success),
                if (widget.state == ViewfinderState.error)
                  Icon(Icons.cancel_outlined,
                      size: 48, color: AppColors.error),
              ],
            ),
          ),

          // Success name label
          if (widget.successName != null &&
              widget.state == ViewfinderState.success) ...[
            const SizedBox(height: 8),
            Text(
              widget.successName!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
