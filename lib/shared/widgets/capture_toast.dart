import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cockado_enrollapp/core/theme/app_colors.dart';

enum ToastType { success, error }

class CaptureToast extends StatefulWidget {
  const CaptureToast({
    super.key,
    required this.type,
    required this.title,
    this.subtitle,
    this.onDismiss,
  });

  final ToastType type;
  final String title;
  final String? subtitle;
  final VoidCallback? onDismiss;

  @override
  State<CaptureToast> createState() => _CaptureToastState();
}

class _CaptureToastState extends State<CaptureToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    _dismissTimer = Timer(const Duration(seconds: 3), _handleDismiss);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    if (!mounted) return;
    widget.onDismiss?.call();
  }

  Color get _accentColor =>
      widget.type == ToastType.success ? AppColors.success : AppColors.error;

  IconData get _iconData =>
      widget.type == ToastType.success ? Icons.check : Icons.close;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: _ToastCard(
            accentColor: _accentColor,
            iconData: _iconData,
            title: widget.title,
            subtitle: widget.subtitle,
            onClose: _handleDismiss,
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.accentColor,
    required this.iconData,
    required this.title,
    required this.onClose,
    this.subtitle,
  });

  final Color accentColor;
  final IconData iconData;
  final String title;
  final String? subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent strip
            Container(
              width: 4.0,
              color: accentColor,
            ),
            // Card body
            Expanded(
              child: Container(
                color: AppColors.darkCard,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 14.0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon circle
                    _IconCircle(
                      color: accentColor,
                      iconData: iconData,
                    ),
                    const SizedBox(width: 12.0),
                    // Text content
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13.0,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2.0),
                            Text(
                              subtitle!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.0,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    // Close button
                    GestureDetector(
                      onTap: onClose,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.close,
                          size: 16.0,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({
    required this.color,
    required this.iconData,
  });

  final Color color;
  final IconData iconData;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36.0,
      height: 36.0,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.0),
      ),
      child: Icon(
        iconData,
        size: 18.0,
        color: color,
      ),
    );
  }
}
