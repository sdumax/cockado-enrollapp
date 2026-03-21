import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cockado_enrollapp/core/theme/app_colors.dart';

class AppStatusBar extends StatelessWidget implements PreferredSizeWidget {
  const AppStatusBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(62.0);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Container(
      height: preferredSize.height,
      color: AppColors.darkBackground,
    );
  }
}
