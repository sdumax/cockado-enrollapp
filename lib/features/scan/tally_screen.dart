import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cockado_enrollapp/core/theme/app_colors.dart';
import '../../shared/widgets/app_status_bar.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/mode_tabs.dart';
import '../../shared/widgets/footer_bar.dart';
import 'scan_providers.dart';

enum _TallyState { idle, success, error }

class TallyScreen extends ConsumerStatefulWidget {
  const TallyScreen({super.key});

  @override
  ConsumerState<TallyScreen> createState() => _TallyScreenState();
}

class _TallyScreenState extends ConsumerState<TallyScreen> {
  final _controller = TextEditingController(text: '0');
  final _focusNode = FocusNode();
  _TallyState _state = _TallyState.idle;
  Timer? _resetTimer;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _appVersion = 'v${info.version}+${info.buildNumber}');
  }

  void _onSubmit() {
    _focusNode.unfocus();
    final value = int.tryParse(_controller.text) ?? 0;
    if (value <= 0) {
      setState(() => _state = _TallyState.error);
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _state = _TallyState.idle);
      });
    } else {
      setState(() => _state = _TallyState.success);
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        setState(() {
          _state = _TallyState.idle;
          _controller.text = '0';
        });
      });
    }
  }

  // ── Derived styles ──────────────────────────────────────────────────────

  Color get _borderColor => switch (_state) {
        _TallyState.idle => const Color(0xFF2563EB),
        _TallyState.success => AppColors.success,
        _TallyState.error => AppColors.error,
      };

  Color get _submitColor => switch (_state) {
        _TallyState.idle => AppColors.blue,
        _TallyState.success => AppColors.success,
        _TallyState.error => AppColors.error,
      };

  Color get _statusBg => switch (_state) {
        _TallyState.idle => Colors.transparent,
        _TallyState.success => const Color(0x40155320),
        _TallyState.error => const Color(0x404B150F),
      };

  Color get _headlineColor => switch (_state) {
        _TallyState.idle => AppColors.textSecondary,
        _TallyState.success => AppColors.success,
        _TallyState.error => AppColors.error,
      };

  Color get _subtitleColor => switch (_state) {
        _TallyState.idle => AppColors.textMuted,
        _TallyState.success => const Color(0xFF86EFAC),
        _TallyState.error => const Color(0xFFFCA5A5),
      };

  String get _headline => switch (_state) {
        _TallyState.idle => 'TALLY MODE',
        _TallyState.success => 'TALLY RECORDED',
        _TallyState.error => 'INVALID TALLY',
      };

  String get _subtitle => switch (_state) {
        _TallyState.idle => 'Enter the tally number',
        _TallyState.success =>
          '${_controller.text} attendees logged',
        _TallyState.error => 'Please enter a valid number',
      };

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Column(
        children: [
          const AppStatusBar(),
          AppHeader(
            title: 'COC-CHECKIN',
            trailing: GestureDetector(
              onTap: () async {
                _focusNode.unfocus();
                await context.push('/settings');
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
                  color: AppColors.textSecondary,
                  size: 18.0,
                ),
              ),
            ),
          ),

          // Tally input area
          Expanded(
            child: ColoredBox(
              color: const Color(0xFF060D1A),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // State icon (visible in success/error)
                      if (_state != _TallyState.idle) ...[
                        SizedBox(
                          width: 48.0,
                          height: 48.0,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 48.0,
                                height: 48.0,
                                decoration: BoxDecoration(
                                  color: _state == _TallyState.success
                                      ? AppColors.success.withAlpha(0x25)
                                      : AppColors.error.withAlpha(0x25),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Icon(
                                _state == _TallyState.success
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.cancel_outlined,
                                color: _state == _TallyState.success
                                    ? AppColors.success
                                    : AppColors.error,
                                size: 32.0,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20.0),
                      ],

                      // Input row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              textAlign: TextAlign.center,
                              onSubmitted: (_) => _onSubmit(),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 32.0,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: 1.0,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF0F1E32),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16.0),
                                  borderSide: BorderSide(
                                    color: _borderColor,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16.0),
                                  borderSide: BorderSide(
                                    color: _borderColor,
                                    width: 2.0,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                  vertical: 18.0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10.0),
                          SizedBox(
                            width: 64.0,
                            height: 64.0,
                            child: ElevatedButton(
                              onPressed: _onSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _submitColor,
                                foregroundColor: AppColors.textPrimary,
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 24.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Status area
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 80.0,
            margin: const EdgeInsets.symmetric(horizontal: 0),
            decoration: BoxDecoration(
              color: _statusBg,
              borderRadius: _state != _TallyState.idle
                  ? BorderRadius.circular(12.0)
                  : BorderRadius.zero,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _headline,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: _headlineColor,
                  ),
                ),
                const SizedBox(height: 6.0),
                Text(
                  _subtitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.0,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.3,
                    color: _subtitleColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Mode tabs
          ModeTabs(
            activeMode: ScanMode.tally,
            onModeChanged: (mode) async {
              _focusNode.unfocus();
              ref.read(activeScanModeProvider.notifier).state = mode;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('lastScanMode', mode.name);
            },
          ),

          // NEW ENROLMENT button
          SizedBox(
            height: 84.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20.0, vertical: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/enrolment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  child: const Text(
                    'NEW ENROLMENT',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ),

          FooterBar(
            version: _appVersion,
            isAutoCapture: false,
          ),
        ],
      ),
    );
  }
}
