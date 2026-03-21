import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' show Value;

import 'package:cockado_enrollapp/core/theme/app_colors.dart';
import 'package:cockado_enrollapp/core/db/app_database.dart';
import 'package:cockado_enrollapp/core/db/database_provider.dart';
import 'package:cockado_enrollapp/core/services/device_id_service.dart';
import 'package:cockado_enrollapp/features/init/sync_status_repository.dart';

import '../../shared/widgets/app_status_bar.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/oval_viewfinder_widget.dart';
import '../../shared/widgets/viewfinder_widget.dart';
import '../../shared/widgets/mode_tabs.dart';
import '../../shared/widgets/footer_bar.dart';
import '../../shared/widgets/capture_toast.dart';
import 'scan_providers.dart';

// ---------------------------------------------------------------------------
// State model
// ---------------------------------------------------------------------------

enum _FaceState { idle, scanning, success, error }

class _MatchResult {
  const _MatchResult({required this.enrollee, required this.score});
  final Enrollee enrollee;
  final double score;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class FaceCaptureScreen extends ConsumerStatefulWidget {
  const FaceCaptureScreen({super.key});

  @override
  ConsumerState<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends ConsumerState<FaceCaptureScreen> {
  // Camera
  CameraController? _cameraController;
  bool _cameraInitialised = false;
  bool _cameraError = false;
  bool _isStreaming = false;

  // Face detector
  late final FaceDetector _faceDetector;

  // Throttle
  static const _frameCooldown = Duration(milliseconds: 200);
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _processingFrame = false;

  // UI state
  _FaceState _faceState = _FaceState.idle;
  _MatchResult? _matched;
  bool _showToast = false;
  String? _toastTitle;
  String? _toastSubtitle;

  // 3-second no-match timer
  static const _scanTimeoutDuration = Duration(seconds: 3);
  DateTime? _scanStartedAt;

  // Reset timer after success
  Timer? _resetTimer;

  // Debounce timer for delayed stream start after mode switch
  Timer? _streamStartTimer;
  static const _streamStartDelay = Duration(milliseconds: 500);

  // App meta
  String _appVersion = '';
  String? _activeEventId;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    // Only init camera if face mode is already active.
    // When the app starts on ticket mode, IndexedStack mounts all screens
    // simultaneously — calling _initCamera() here would open a CameraController
    // session that conflicts with MobileScannerController.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(activeScanModeProvider) == ScanMode.face) {
        _initCamera();
      }
    });
    _loadMeta();
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _streamStartTimer?.cancel();
    _stopStreaming();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  // ── Streaming control ─────────────────────────────────────────────────────

  void _stopStreaming() {
    if (!_isStreaming || _cameraController == null) return;
    _cameraController!.stopImageStream();
    _isStreaming = false;
  }

  void _startStreaming() {
    if (_isStreaming || _cameraController == null || !_cameraInitialised) return;
    _cameraController!.startImageStream(_onCameraFrame);
    _isStreaming = true;
  }

  // Stops streaming AND fully disposes the CameraController, releasing the
  // camera hardware so MobileScannerController can open it on ticket mode.
  Future<void> _releaseCamera() async {
    _stopStreaming();
    final c = _cameraController;
    _cameraController = null;
    if (mounted) setState(() => _cameraInitialised = false);
    await c?.dispose();
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> _loadMeta() async {
    final info = await PackageInfo.fromPlatform();
    final repo = ref.read(syncStatusRepositoryProvider);
    final eventId = await repo.getActiveEventId();
    if (!mounted) return;
    setState(() {
      _appVersion = 'v${info.version}+${info.buildNumber}';
      _activeEventId = eventId;
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() => _cameraError = true);
        return;
      }

      // Prefer front camera for face enrolment / recognition.
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      setState(() => _cameraInitialised = true);

      // Guard: user may have switched away while async init was in flight.
      if (!mounted || ref.read(activeScanModeProvider) != ScanMode.face) return;
      await controller.startImageStream(_onCameraFrame);
      _isStreaming = true;
    } on CameraException {
      if (!mounted) return;
      setState(() => _cameraError = true);
    }
  }

  // ── Camera frame pipeline ─────────────────────────────────────────────────

  void _onCameraFrame(CameraImage image) {
    if (_processingFrame) return;
    if (_faceState == _FaceState.success) return;

    final now = DateTime.now();
    if (now.difference(_lastFrameAt) < _frameCooldown) return;

    _processingFrame = true;
    _lastFrameAt = now;
    _detectFace(image).whenComplete(() => _processingFrame = false);
  }

  Future<void> _detectFace(CameraImage image) async {
    final InputImage mlImage;
    try {
      mlImage = _toInputImage(image);
    } catch (_) {
      return;
    }

    List<Face> faces;
    try {
      faces = await _faceDetector.processImage(mlImage);
    } catch (_) {
      return;
    }

    if (!mounted) return;

    if (faces.isEmpty) {
      if (_faceState == _FaceState.scanning) {
        // Check whether the 3-second timeout has elapsed.
        if (_scanStartedAt != null &&
            DateTime.now().difference(_scanStartedAt!) >=
                _scanTimeoutDuration) {
          // Stay in scanning — operator can use tally fallback.
          // Reset the timer so we don't spam state changes.
          _scanStartedAt = DateTime.now();
        }
      } else {
        setState(() => _faceState = _FaceState.idle);
        ref.read(captureActiveProvider.notifier).state = false;
      }
      return;
    }

    // Face detected — move to scanning if not already past that.
    if (_faceState == _FaceState.idle) {
      setState(() {
        _faceState = _FaceState.scanning;
        _scanStartedAt = DateTime.now();
      });
      ref.read(captureActiveProvider.notifier).state = true;
    }

    // Attempt match (stub: always returns null until Phase 9).
    final match = await _matchFace();
    if (!mounted) return;

    if (match != null) {
      await _handleSuccess(match);
    }
  }

  InputImage _toInputImage(CameraImage image) {
    final camera = _cameraController!.description;
    final rotation = _sensorOrientationToInputImageRotation(
      camera.sensorOrientation,
      camera.lensDirection,
    );

    final plane = image.planes.first;
    final bytes = plane.bytes;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation _sensorOrientationToInputImageRotation(
    int sensorOrientation,
    CameraLensDirection lensDirection,
  ) {
    switch (sensorOrientation) {
      case 90:
        return lensDirection == CameraLensDirection.front
            ? InputImageRotation.rotation270deg
            : InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return lensDirection == CameraLensDirection.front
            ? InputImageRotation.rotation90deg
            : InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  // ── Face matching stub ────────────────────────────────────────────────────

  /// Generates a 128-float placeholder embedding.  Real TFLite inference
  /// is wired up in Phase 9.
  List<double> _generatePlaceholderEmbedding() {
    final rand = math.Random();
    final vec = List<double>.generate(128, (_) => rand.nextDouble() * 2 - 1);
    // L2-normalise
    final norm =
        math.sqrt(vec.fold<double>(0.0, (sum, v) => sum + v * v));
    return vec.map((v) => v / (norm == 0 ? 1 : norm)).toList();
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = math.sqrt(normA) * math.sqrt(normB);
    return denom == 0 ? 0.0 : dot / denom;
  }

  /// Returns a match if cosine similarity > 0.75, otherwise null.
  /// Currently always returns null (placeholder embedding vs stored
  /// embeddings will never exceed threshold until Phase 9 wires real
  /// TFLite inference).
  Future<_MatchResult?> _matchFace() async {
    final db = ref.read(databaseProvider);
    final candidates = await db.enrolleesDao.getWithFaceEmbedding();

    if (candidates.isEmpty) return null;

    final queryEmbedding = _generatePlaceholderEmbedding();
    _MatchResult? best;
    double bestScore = 0.75; // minimum threshold

    for (final enrollee in candidates) {
      final raw = enrollee.faceEmbedding;
      if (raw == null) continue;
      final stored = _bytesToFloats(raw);
      if (stored.isEmpty) continue;
      final score = _cosineSimilarity(queryEmbedding, stored);
      if (score > bestScore) {
        bestScore = score;
        best = _MatchResult(enrollee: enrollee, score: score);
      }
    }

    return best;
  }

  List<double> _bytesToFloats(Uint8List bytes) {
    if (bytes.length % 4 != 0) return [];
    final buffer = bytes.buffer;
    final floats = buffer.asFloat32List();
    return floats.map((f) => f.toDouble()).toList();
  }

  // ── Success flow ──────────────────────────────────────────────────────────

  Future<void> _handleSuccess(_MatchResult match) async {
    setState(() {
      _faceState = _FaceState.success;
      _matched = match;
    });

    await _writeCheckin(match.enrollee);

    if (!mounted) return;
    setState(() {
      _showToast = true;
      _toastTitle = 'IDENTITY CONFIRMED';
      _toastSubtitle = match.enrollee.fullName;
    });

    _resetTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() {
        _faceState = _FaceState.scanning;
        _matched = null;
        _showToast = false;
        _scanStartedAt = DateTime.now();
      });
      ref.read(captureActiveProvider.notifier).state = true;
    });
  }

  Future<void> _writeCheckin(Enrollee enrollee) async {
    if (_activeEventId == null) return;
    final db = ref.read(databaseProvider);
    final already = await db.checkinsDao
        .hasCheckinForEvent(enrollee.id, _activeEventId!);
    if (already) return;

    final deviceId =
        await ref.read(deviceIdServiceProvider).getDeviceId();

    await db.checkinsDao.insertCheckin(
      CheckinsCompanion(
        enrolleeId: Value(enrollee.id),
        eventId: Value(_activeEventId!),
        method: const Value('FACE'),
        deviceId: Value(deviceId),
        timestamp: Value(DateTime.now()),
        syncStatus: const Value('PENDING'),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  ViewfinderState get _viewfinderState => switch (_faceState) {
        _FaceState.idle => ViewfinderState.idle,
        _FaceState.scanning => ViewfinderState.scanning,
        _FaceState.success => ViewfinderState.success,
        _FaceState.error => ViewfinderState.error,
      };

  (String, String) get _statusText => switch (_faceState) {
        _FaceState.idle => ('READY', 'Position your face within the oval'),
        _FaceState.scanning => ('SCANNING...', 'Hold still'),
        _FaceState.success => (
            'IDENTITY CONFIRMED',
            _matched?.enrollee.fullName ?? '',
          ),
        _FaceState.error => (
            'NOT RECOGNISED',
            'Please try again or use tally fallback',
          ),
      };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<ScanMode>(activeScanModeProvider, (prev, next) {
      if (next != ScanMode.face) {
        // Fully release the camera so the ticket scanner can open it.
        _streamStartTimer?.cancel();
        _releaseCamera();
      } else if (prev != ScanMode.face) {
        // Switching TO face — wait for any outgoing camera release to complete
        // before we init/start, then decide based on initialisation state.
        _streamStartTimer?.cancel();
        _streamStartTimer = Timer(_streamStartDelay, () {
          if (!mounted || ref.read(activeScanModeProvider) != ScanMode.face) {
            return;
          }
          if (!_cameraInitialised) {
            // First visit to face mode — init from scratch.
            _initCamera();
          } else {
            // Camera already initialised from a previous visit — just stream.
            _startStreaming();
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          _buildMainLayout(),
          if (_showToast && _toastTitle != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: CaptureToast(
                  type: ToastType.success,
                  title: _toastTitle!,
                  subtitle: _toastSubtitle,
                  onDismiss: () {
                    if (mounted) setState(() => _showToast = false);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainLayout() {
    return Column(
      children: [
        // Status bar
        const AppStatusBar(),

        // Header
        AppHeader(
          title: 'COC-CHECKIN',
          trailing: GestureDetector(
            onTap: () async {
              _stopStreaming();
              await context.push('/settings');
              if (mounted && ref.read(activeScanModeProvider) == ScanMode.face) {
                _startStreaming();
              }
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

        // Camera + viewfinder (442 px)
        _buildCameraArea(),

        // Status text (80 px)
        _buildStatusArea(),

        // Mode tabs
        ModeTabs(
          activeMode: ScanMode.face,
          onModeChanged: (mode) async {
            ref.read(activeScanModeProvider.notifier).state = mode;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('lastScanMode', mode.name);
          },
        ),

        // NEW ENROLMENT button (84 px)
        _buildEnrolmentButton(),

        // Footer
        FooterBar(
          version: _appVersion,
          isAutoCapture: true,
        ),
      ],
    );
  }

  Widget _buildCameraArea() {
    return Expanded(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_cameraInitialised && _cameraController != null)
            ClipRect(
              child: OverflowBox(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize?.height ?? 1,
                    height: _cameraController!.value.previewSize?.width ?? 1,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
            )
          else if (_cameraError)
            _CameraErrorPlaceholder()
          else
            _CameraLoadingPlaceholder(),

          // Oval viewfinder centred
          Center(
            child: OvalViewfinderWidget(
              state: _viewfinderState,
              successName: _matched?.enrollee.fullName,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusArea() {
    final (headline, sub) = _statusText;
    final headlineColor = switch (_faceState) {
      _FaceState.idle => AppColors.textSecondary,
      _FaceState.scanning => AppColors.blueLight,
      _FaceState.success => AppColors.success,
      _FaceState.error => AppColors.error,
    };

    return SizedBox(
      height: 80.0,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            headline,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: headlineColor,
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            sub,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.0,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.3,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


  Widget _buildEnrolmentButton() {
    return SizedBox(
      height: 84.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
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
    );
  }
}

// ---------------------------------------------------------------------------
// Helper placeholders
// ---------------------------------------------------------------------------

class _CameraLoadingPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.darkBackground,
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.blue,
          strokeWidth: 2.0,
        ),
      ),
    );
  }
}

class _CameraErrorPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.darkBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              color: AppColors.textMuted,
              size: 40.0,
            ),
            SizedBox(height: 12.0),
            Text(
              'CAMERA UNAVAILABLE',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
