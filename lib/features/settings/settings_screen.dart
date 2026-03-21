import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cockado_enrollapp/core/theme/app_colors.dart';
import 'package:cockado_enrollapp/core/services/connectivity_service.dart';
import 'package:cockado_enrollapp/features/init/sync_status_repository.dart';
import 'package:cockado_enrollapp/features/scan/scan_providers.dart';
import 'package:cockado_enrollapp/shared/widgets/option_sheet.dart';

// ---------------------------------------------------------------------------
// Theme mode provider
// Phase 9 will wire CocCheckinApp in main.dart to watch this provider and
// pass the value to MaterialApp.router's themeMode parameter.
// ---------------------------------------------------------------------------
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

// ---------------------------------------------------------------------------
// Last sync FutureProvider
// ---------------------------------------------------------------------------
final _lastSyncProvider = FutureProvider<String?>((ref) async {
  final repo = ref.watch(syncStatusRepositoryProvider);
  return repo.getLastSyncedAt();
});

// ---------------------------------------------------------------------------
// SettingsScreen
// ---------------------------------------------------------------------------
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  SharedPreferences? _prefs;

  bool _audioBeep = true;
  bool _hapticFeedback = true;
  String _cameraFacing = 'REAR';

  String _activeEvent = 'TECH SUMMIT 2026 — DAY 1';
  static const List<String> _eventOptions = [
    'TECH SUMMIT 2026 — DAY 1',
    'YOUTH CONFERENCE 2026',
  ];

  static const List<String> _cameraFacingOptions = ['REAR', 'FRONT'];

  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadPackageInfo();
    // Prevent the ScanScreen inactivity timer from sending the user to standby
    // while they are configuring settings.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(standbyInhibitedProvider.notifier).state = true;
    });
  }

  @override
  void dispose() {
    ref.read(standbyInhibitedProvider.notifier).state = false;
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _prefs = prefs;
      _audioBeep = prefs.getBool('pref_audio_beep') ?? true;
      _hapticFeedback = prefs.getBool('pref_haptic_feedback') ?? true;
      _cameraFacing = prefs.getString('pref_camera_facing') ?? 'REAR';
    });
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _packageInfo = info);
  }

  Future<void> _setAudioBeep(bool value) async {
    await _prefs?.setBool('pref_audio_beep', value);
    setState(() => _audioBeep = value);
  }

  Future<void> _setHapticFeedback(bool value) async {
    await _prefs?.setBool('pref_haptic_feedback', value);
    setState(() => _hapticFeedback = value);
  }

  Future<void> _setCameraFacing(String value) async {
    await _prefs?.setString('pref_camera_facing', value);
    setState(() => _cameraFacing = value);
    // Notify the ticket scanner to switch cameras immediately.
    ref.read(scanCameraFacingProvider.notifier).state = value;
  }

  Future<void> _showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'LOGOUT',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'LOGOUT',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Phase 8 will clear auth state and navigate to login.
      // ignore: use_build_context_synchronously
      context.go('/login');
    }
  }

  Future<void> _showEventSheet() async {
    final currentIndex = _eventOptions.indexOf(_activeEvent);
    final selected = await OptionSheet.show(
      context,
      title: 'Select Active Event',
      options: _eventOptions,
      selectedIndex: currentIndex < 0 ? 0 : currentIndex,
    );
    if (selected != null && mounted) {
      setState(() => _activeEvent = _eventOptions[selected]);
    }
  }

  Future<void> _showCameraFacingSheet() async {
    final currentIndex = _cameraFacingOptions.indexOf(_cameraFacing);
    final selected = await OptionSheet.show(
      context,
      title: 'Scan Camera',
      options: _cameraFacingOptions,
      selectedIndex: currentIndex < 0 ? 0 : currentIndex,
    );
    if (selected != null && mounted) {
      await _setCameraFacing(_cameraFacingOptions[selected]);
    }
  }

  void _toggleTheme() {
    final current = ref.read(themeModeProvider);
    ref.read(themeModeProvider.notifier).state =
        current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isOnlineAsync = ref.watch(isOnlineProvider);
    final lastSyncAsync = ref.watch(_lastSyncProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: SafeArea(
          child: Column(
            children: [
              // ── Custom header ──────────────────────────────────────────
              _SettingsHeader(
                themeMode: themeMode,
                onBack: () => context.pop(),
                onThemeToggle: _toggleTheme,
              ),
              // ── Scrollable content ─────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ACCOUNT
                      _SectionLabel(label: 'ACCOUNT'),
                      _SectionCard(
                        children: [
                          _AccountRow(),
                          const _Divider(),
                          _LogoutRow(onTap: _showLogoutDialog),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // NETWORK
                      _SectionLabel(label: 'NETWORK'),
                      _SectionCard(
                        children: [
                          _ConnectionRow(isOnlineAsync: isOnlineAsync),
                          const _Divider(),
                          _LastSyncRow(lastSyncAsync: lastSyncAsync),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ACTIVE EVENT
                      _SectionLabel(label: 'ACTIVE EVENT'),
                      _SectionCard(
                        children: [
                          _ActiveEventRow(
                            eventName: _activeEvent,
                            onTap: _showEventSheet,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // CAPTURE SETTINGS
                      _SectionLabel(label: 'CAPTURE SETTINGS'),
                      _SectionCard(
                        children: [
                          _ToggleRow(
                            label: 'AUDIO BEEP',
                            value: _audioBeep,
                            onTap: () => _setAudioBeep(!_audioBeep),
                          ),
                          const _Divider(),
                          _ToggleRow(
                            label: 'HAPTIC FEEDBACK',
                            value: _hapticFeedback,
                            onTap: () => _setHapticFeedback(!_hapticFeedback),
                          ),
                          const _Divider(),
                          _CameraFacingRow(
                            value: _cameraFacing,
                            onTap: _showCameraFacingSheet,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ABOUT
                      _SectionLabel(label: 'ABOUT'),
                      _SectionCard(
                        children: [
                          _AppVersionRow(packageInfo: _packageInfo),
                          const _Divider(),
                          _DiagnosticsRow(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Diagnostics exported'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------
class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.themeMode,
    required this.onBack,
    required this.onThemeToggle,
  });

  final ThemeMode themeMode;
  final VoidCallback onBack;
  final VoidCallback onThemeToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Back button
            GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Icon(
                    Icons.chevron_left,
                    color: AppColors.textPrimary,
                    size: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'SETTINGS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Theme toggle
            GestureDetector(
              onTap: onThemeToggle,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.darkCard,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Layout helpers
// ---------------------------------------------------------------------------
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.darkDivider,
      indent: 16,
      endIndent: 16,
    );
  }
}

// Base row layout
class _BaseRow extends StatelessWidget {
  const _BaseRow({
    required this.leading,
    required this.label,
    this.sublabel,
    this.trailing,
    this.onTap,
    this.height = 48,
  });

  final Widget leading;
  final Widget label;
  final Widget? sublabel;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    Widget content = SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: sublabel != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label,
                        const SizedBox(height: 2),
                        sublabel!,
                      ],
                    )
                  : label,
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        splashColor: AppColors.darkDivider.withValues(alpha: 0.4),
        highlightColor: AppColors.darkDivider.withValues(alpha: 0.2),
        child: content,
      );
    }
    return content;
  }
}

// ---------------------------------------------------------------------------
// ACCOUNT rows
// ---------------------------------------------------------------------------
class _AccountRow extends StatelessWidget {
  const _AccountRow();

  @override
  Widget build(BuildContext context) {
    return _BaseRow(
      leading: const Icon(
        Icons.person_outline,
        color: AppColors.blue,
        size: 20,
      ),
      label: const Text(
        'Operator',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      sublabel: null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'OPERATOR · #OP-042',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutRow extends StatelessWidget {
  const _LogoutRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BaseRow(
      onTap: onTap,
      leading: const Icon(Icons.logout, color: AppColors.error, size: 20),
      label: const Text(
        'LOGOUT',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: AppColors.error,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.error,
        size: 20,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NETWORK rows
// ---------------------------------------------------------------------------
class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({required this.isOnlineAsync});

  final AsyncValue<bool> isOnlineAsync;

  @override
  Widget build(BuildContext context) {
    final isOnline = isOnlineAsync.valueOrNull ?? false;

    return _BaseRow(
      leading: Icon(
        isOnline ? Icons.wifi : Icons.wifi_off,
        color: isOnline ? AppColors.success : AppColors.error,
        size: 20,
      ),
      label: const Text(
        'CONNECTION',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isOnline ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isOnline ? AppColors.success : AppColors.error,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOnline ? AppColors.success : AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _LastSyncRow extends StatelessWidget {
  const _LastSyncRow({required this.lastSyncAsync});

  final AsyncValue<String?> lastSyncAsync;

  @override
  Widget build(BuildContext context) {
    final raw = lastSyncAsync.valueOrNull;
    String displayValue = '—';

    if (raw != null) {
      try {
        final dt = DateTime.parse(raw).toLocal();
        final hour = dt.hour.toString().padLeft(2, '0');
        final min = dt.minute.toString().padLeft(2, '0');
        displayValue = '${dt.day}/${dt.month}/${dt.year} $hour:$min';
      } catch (_) {
        displayValue = raw;
      }
    }

    return _BaseRow(
      leading: const Icon(
        Icons.sync,
        color: AppColors.textMuted,
        size: 20,
      ),
      label: const Text(
        'LAST SYNC',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Text(
        displayValue,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ACTIVE EVENT row
// ---------------------------------------------------------------------------
class _ActiveEventRow extends StatelessWidget {
  const _ActiveEventRow({required this.eventName, required this.onTap});

  final String eventName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BaseRow(
      height: 56,
      onTap: onTap,
      leading: const Icon(
        Icons.event_outlined,
        color: AppColors.blue,
        size: 20,
      ),
      label: Text(
        eventName,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      sublabel: const Text(
        'ACTIVE EVENT',
        style: TextStyle(
          fontSize: 10,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.8,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textMuted,
        size: 20,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CAPTURE SETTINGS rows
// ---------------------------------------------------------------------------
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BaseRow(
      onTap: onTap,
      leading: Icon(
        value ? Icons.volume_up_outlined : Icons.volume_off_outlined,
        color: AppColors.textMuted,
        size: 20,
      ),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Text(
        value ? 'ON' : 'OFF',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: value ? AppColors.blue : AppColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _CameraFacingRow extends StatelessWidget {
  const _CameraFacingRow({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BaseRow(
      onTap: onTap,
      leading: Icon(
        value == 'FRONT' ? Icons.camera_front_outlined : Icons.camera_rear_outlined,
        color: AppColors.textMuted,
        size: 20,
      ),
      label: const Text(
        'SCAN CAMERA',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ABOUT rows
// ---------------------------------------------------------------------------
class _AppVersionRow extends StatelessWidget {
  const _AppVersionRow({required this.packageInfo});

  final PackageInfo? packageInfo;

  @override
  Widget build(BuildContext context) {
    final version = packageInfo?.version ?? '1.0.0';
    final build = packageInfo?.buildNumber ?? '42';

    return _BaseRow(
      height: 52,
      leading: const Icon(
        Icons.info_outline,
        color: AppColors.blue,
        size: 20,
      ),
      label: const Text(
        'COC-CHECKIN',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      sublabel: Text(
        'Version $version · Build $build',
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _DiagnosticsRow extends StatelessWidget {
  const _DiagnosticsRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BaseRow(
      onTap: onTap,
      leading: const Icon(
        Icons.bug_report_outlined,
        color: AppColors.textMuted,
        size: 20,
      ),
      label: const Text(
        'SEND DIAGNOSTICS',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textMuted,
        size: 20,
      ),
    );
  }
}
