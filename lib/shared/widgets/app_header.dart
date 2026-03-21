import 'package:flutter/material.dart';
import 'package:cockado_enrollapp/core/theme/app_colors.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.showBack = false,
    this.onBack,
    this.trailing,
  });

  final String title;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64.0,
      color: AppColors.darkBackground,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBack)
            GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 32.0,
                height: 32.0,
                decoration: const BoxDecoration(
                  color: AppColors.darkCard,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_left,
                  color: AppColors.textSecondary,
                  size: 20.0,
                ),
              ),
            )
          else
            const SizedBox(width: 32.0),
          Expanded(
            child: Center(
              child: Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          if (trailing != null)
            trailing!
          else
            const SizedBox(width: 32.0),
        ],
      ),
    );
  }
}
