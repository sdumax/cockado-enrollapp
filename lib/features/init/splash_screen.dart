import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cockado_enrollapp/core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotController;
  late final List<Animation<double>> _dotScales;
  Timer? _navTimer;
  String _version = '';

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    const delays = [0.0, 200.0, 400.0];
    _dotScales = delays.map((delayMs) {
      final delayFraction = delayMs / 1200.0;
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.4)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.4, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: ConstantTween(1.0),
          weight: 40,
        ),
      ]).animate(
        CurvedAnimation(
          parent: _dotController,
          curve: Interval(
            delayFraction,
            (delayFraction + 0.5).clamp(0.0, 1.0),
            curve: Curves.linear,
          ),
        ),
      );
    }).toList();

    _loadVersion();

    _navTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        context.go('/scan');
      }
    });
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = 'V${info.version}';
      });
    }
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _dotController.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LogoPlaceholder(),
                const SizedBox(height: 12),
                const Text(
                  'COC-CHECKIN',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'CHURCH OF CHRIST',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 3,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 40),
                _LoadingDots(dotScales: _dotScales, controller: _dotController),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _version,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/church_logo.png',
      width: 96,
      height: 96,
    );
  }
}

class _LoadingDots extends StatelessWidget {
  final List<Animation<double>> dotScales;
  final AnimationController controller;

  const _LoadingDots({
    required this.dotScales,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Padding(
              padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
              child: Transform.scale(
                scale: dotScales[index].value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
