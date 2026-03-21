import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' show Value;
import 'package:cockado_enrollapp/core/theme/app_colors.dart';
import 'package:cockado_enrollapp/core/db/database_provider.dart';
import 'package:cockado_enrollapp/core/db/app_database.dart';
import 'package:cockado_enrollapp/core/services/device_id_service.dart';
import 'package:cockado_enrollapp/features/init/sync_status_repository.dart';
import '../../shared/widgets/app_status_bar.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/viewfinder_widget.dart';
import '../../shared/widgets/mode_tabs.dart';
import '../../shared/widgets/footer_bar.dart';
import '../../shared/widgets/capture_toast.dart';
import 'scan_providers.dart';

class TicketScanScreen extends ConsumerStatefulWidget {
  const TicketScanScreen({super.key});

  @override
  ConsumerState<TicketScanScreen> createState() => _TicketScanScreenState();
}

class _TicketScanScreenState extends ConsumerState<TicketScanScreen> {
  late final MobileScannerController _scannerController;

  ViewfinderState _viewfinderState = ViewfinderState.idle;
  String _statusMain = 'READY TO SCAN';
  String _statusSub = 'Position ticket or ID within the frame';
  String? _successName;

  bool _showToast = false;
  String _toastSubtitle = '';

  bool _isBusy = false;
  Timer? _resetTimer;

  // Debounce timer for delayed stream start after mode switch
  Timer? _streamStartTimer;
  static const _streamStartDelay = Duration(milliseconds: 500);

  String _version = '';

  @override
  void initState() {
    super.initState();
    // autoStart: false — prevents MobileScanner from grabbing the camera
    // immediately when built inside IndexedStack, even when another mode is
    // active.  We start it manually once we know ticket mode is the active one.
    _scannerController = _buildController(ref.read(scanCameraFacingProvider));
    _loadVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Sync the provider with the persisted preference so the correct camera
      // is used even if Settings was never opened in this session.
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('pref_camera_facing') ?? 'REAR';
      if (!mounted) return;
      if (saved != ref.read(scanCameraFacingProvider)) {
        // Updating the provider triggers the ref.listen which recreates the
        // controller and starts streaming — no need to call _startStreaming here.
        ref.read(scanCameraFacingProvider.notifier).state = saved;
      } else if (ref.read(activeScanModeProvider) == ScanMode.ticket) {
        _startStreaming();
      }
    });
  }

  MobileScannerController _buildController(String facing) {
    return MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: facing == 'FRONT' ? CameraFacing.front : CameraFacing.back,
    );
  }

  Future<void> _recreateScannerController(String facing) async {
    final wasStreaming = ref.read(activeScanModeProvider) == ScanMode.ticket;
    await _scannerController.dispose();
    _scannerController = _buildController(facing);
    if (mounted) {
      setState(() {});
      if (wasStreaming) _startStreaming();
    }
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = 'v${info.version}+${info.buildNumber}';
      });
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _streamStartTimer?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  // ── Streaming control ─────────────────────────────────────────────────────

  void _stopStreaming() {
    _scannerController.stop();
  }

  void _startStreaming() {
    _scannerController.start();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isBusy) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    _processBarcode(rawValue);
  }

  Future<void> _processBarcode(String value) async {
    ref.read(captureActiveProvider.notifier).state = true;
    setState(() {
      _isBusy = true;
      _viewfinderState = ViewfinderState.scanning;
      _statusMain = 'SCANNING...';
      _statusSub = '';
      _successName = null;
      _showToast = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 300));

    try {
      final db = ref.read(databaseProvider);
      final enrollee = await db.enrolleesDao.getByTally(value);

      if (enrollee != null) {
        final eventId =
            await ref.read(syncStatusRepositoryProvider).getActiveEventId();
        final deviceId = ref.read(deviceIdProvider).value ?? 'unknown';

        await db.checkinsDao.insertCheckin(CheckinsCompanion(
          enrolleeId: Value(enrollee.id),
          eventId: Value(eventId ?? 'unknown'),
          method: const Value('TICKET'),
          deviceId: Value(deviceId),
          timestamp: Value(DateTime.now()),
          syncStatus: const Value('PENDING'),
        ));

        if (mounted) {
          setState(() {
            _viewfinderState = ViewfinderState.success;
            _statusMain = 'SCAN COMPLETE';
            _successName = enrollee.fullName;
            _statusSub = enrollee.fullName;
            _showToast = true;
            _toastSubtitle = enrollee.fullName;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _viewfinderState = ViewfinderState.error;
            _statusMain = 'SCAN FAILED';
            _statusSub = 'Barcode not recognised';
            _showToast = true;
            _toastSubtitle = 'Barcode not recognised';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _viewfinderState = ViewfinderState.error;
          _statusMain = 'SCAN FAILED';
          _statusSub = 'Barcode not recognised';
          _showToast = true;
          _toastSubtitle = 'Barcode not recognised';
        });
      }
    }

    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 2500), _resetToIdle);
  }

  void _resetToIdle() {
    if (!mounted) return;
    ref.read(captureActiveProvider.notifier).state = false;
    setState(() {
      _viewfinderState = ViewfinderState.idle;
      _statusMain = 'READY TO SCAN';
      _statusSub = 'Position ticket or ID within the frame';
      _successName = null;
      _isBusy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(scanCameraFacingProvider, (prev, next) {
      if (prev != next) _recreateScannerController(next);
    });

    ref.listen<ScanMode>(activeScanModeProvider, (prev, next) {
      if (next != ScanMode.ticket) {
        _streamStartTimer?.cancel();
        _stopStreaming();
      } else if (prev != ScanMode.ticket) {
        _streamStartTimer?.cancel();
        _streamStartTimer = Timer(_streamStartDelay, () {
          if (mounted && ref.read(activeScanModeProvider) == ScanMode.ticket) {
            _startStreaming();
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Column(
        children: [
          // Status bar (62px)
          const AppStatusBar(),

          // Header
          AppHeader(
            title: 'COC-CHECKIN',
            trailing: GestureDetector(
              onTap: () async {
                _stopStreaming();
                await context.push('/settings');
                if (mounted && ref.read(activeScanModeProvider) == ScanMode.ticket) {
                  _startStreaming();
                }
              },
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.settings_outlined,
                  size: 22.0,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),

          // Camera area — expands to fill available space
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Camera preview
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),

                // Viewfinder overlay
                Center(
                  child: ViewfinderWidget(
                    state: _viewfinderState,
                    successName: _successName,
                  ),
                ),

                // Toast overlay
                if (_showToast)
                  Positioned(
                    top: 72,
                    left: 16,
                    right: 16,
                    child: CaptureToast(
                      type: _viewfinderState == ViewfinderState.success
                          ? ToastType.success
                          : ToastType.error,
                      title: _viewfinderState == ViewfinderState.success
                          ? 'Check-in recorded'
                          : 'Not found',
                      subtitle: _toastSubtitle,
                      onDismiss: () => setState(() => _showToast = false),
                    ),
                  ),
              ],
            ),
          ),

          // Status text area (80px)
          SizedBox(
            height: 80.0,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _statusMain,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_statusSub.isNotEmpty) ...[
                    const SizedBox(height: 6.0),
                    Text(
                      _statusSub,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.0,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.3,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Mode tabs (64px)
          ModeTabs(
            activeMode: ScanMode.ticket,
            onModeChanged: (mode) async {
              ref.read(activeScanModeProvider.notifier).state = mode;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('lastScanMode', mode.name);
            },
          ),

          // NEW ENROLMENT button (84px)
          SizedBox(
            height: 84.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/enrolment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(
                    Icons.person_add_outlined,
                    size: 18.0,
                  ),
                  label: const Text(
                    'NEW ENROLMENT',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Footer bar
          FooterBar(version: _version),
        ],
      ),
    );
  }
}
