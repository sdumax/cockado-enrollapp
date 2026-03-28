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
import 'package:tflite_flutter/tflite_flutter.dart';

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

enum _FaceHint { none, noFace, moveCloser, moveBack, centerFace, lookStraight }

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

  // TFLite interpreter for MobileFaceNet
  Interpreter? _interpreter;

  // Throttle
  static const _frameCooldown = Duration(milliseconds: 200);
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _processingFrame = false;

  // UI state
  _FaceState _faceState = _FaceState.idle;
  _FaceHint _hint = _FaceHint.noFace;
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
    _loadModel();
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
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/mobilefacenet.tflite',
      );
    } catch (_) {
      // Model failed to load — matching will return null until resolved.
    }
  }

  // ── Streaming control ─────────────────────────────────────────────────────

  void _stopStreaming() {
    if (!_isStreaming || _cameraController == null) return;
    _cameraController!.stopImageStream();
    _isStreaming = false;
  }

  void _startStreaming() {
    if (_isStreaming || _cameraController == null || !_cameraInitialised) {
      return;
    }
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

      // Use the camera facing set in Settings (default: rear).
      final facing = ref.read(scanCameraFacingProvider);
      final preferredDirection = facing == 'FRONT'
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == preferredDirection,
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
        if (_scanStartedAt != null &&
            DateTime.now().difference(_scanStartedAt!) >=
                _scanTimeoutDuration) {
          _scanStartedAt = DateTime.now();
        }
      } else {
        setState(() {
          _faceState = _FaceState.idle;
          _hint = _FaceHint.noFace;
        });
        ref.read(captureActiveProvider.notifier).state = false;
      }
      return;
    }

    // Face detected — compute positioning hint.
    final hint = _computeHint(faces.first, image);

    // Move to scanning if not already past that.
    if (_faceState == _FaceState.idle) {
      setState(() {
        _faceState = _FaceState.scanning;
        _scanStartedAt = DateTime.now();
        _hint = hint;
      });
      ref.read(captureActiveProvider.notifier).state = true;
    } else {
      if (mounted) setState(() => _hint = hint);
    }

    final match = await _matchFace(image, faces.first);
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

  // ── Face guidance hints ───────────────────────────────────────────────────

  _FaceHint _computeHint(Face face, CameraImage image) {
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final bb = face.boundingBox;

    // Size: compare average face dimension to shorter image side.
    final faceSize = (bb.width + bb.height) / 2;
    final shortSide = imgW < imgH ? imgW : imgH;
    final ratio = faceSize / shortSide;
    if (ratio < 0.20) return _FaceHint.moveCloser;
    if (ratio > 0.75) return _FaceHint.moveBack;

    // Centering: face centre should be within 25% of image centre.
    final cx = bb.center.dx / imgW;
    final cy = bb.center.dy / imgH;
    if ((cx - 0.5).abs() > 0.25 || (cy - 0.5).abs() > 0.25) {
      return _FaceHint.centerFace;
    }

    // Head angle: yaw and pitch within ±25°.
    final yaw = face.headEulerAngleY ?? 0.0;
    final pitch = face.headEulerAngleX ?? 0.0;
    if (yaw.abs() > 25 || pitch.abs() > 25) return _FaceHint.lookStraight;

    return _FaceHint.none;
  }

  // ── Face matching (MobileFaceNet TFLite) ─────────────────────────────────

  /// Runs MobileFaceNet on the detected face crop and compares against all
  /// stored embeddings. Returns the best match above the 0.75 threshold.
  Future<_MatchResult?> _matchFace(CameraImage image, Face face) async {
    if (_interpreter == null) return null;

    final input = _preprocessFace(image, face.boundingBox);
    if (input == null) return null;

    // Run inference: input [1,112,112,3], output [1,128]
    final outputBuffer = List.filled(128, 0.0);
    final output = [outputBuffer];
    try {
      _interpreter!.run(
        [input.reshape([112, 112, 3])],
        output,
      );
    } catch (_) {
      return null;
    }

    final embedding = _l2Normalize(List<double>.from(outputBuffer));
    debugPrint('[FaceCapture] embedding (128-d): $embedding');

    // DEBUG: stop streaming immediately after first embed log.
    _stopStreaming();
    return null;

    // ignore: dead_code
    final db = ref.read(databaseProvider);
    final candidates = await db.enrolleesDao.getWithFaceEmbedding();
    if (candidates.isEmpty) return null;

    _MatchResult? best;
    double bestScore = 0.75; // minimum cosine similarity threshold

    for (final enrollee in candidates) {
      final raw = enrollee.faceEmbedding;
      if (raw == null) continue;
      final stored = _bytesToFloats(raw);
      if (stored.isEmpty) continue;
      final score = _cosineSimilarity(embedding, stored);
      if (score > bestScore) {
        bestScore = score;
        best = _MatchResult(enrollee: enrollee, score: score);
      }
    }

    return best;
  }

  /// Crops the face bounding box from a NV21 CameraImage, converts YUV→RGB,
  /// resizes to 112×112, and normalises pixels to [-1, 1].
  Float32List? _preprocessFace(CameraImage image, Rect boundingBox) {
    const targetSize = 112;
    final imgW = image.width;
    final imgH = image.height;

    final left = boundingBox.left.clamp(0.0, imgW - 1.0).toInt();
    final top = boundingBox.top.clamp(0.0, imgH - 1.0).toInt();
    final right = boundingBox.right.clamp(1.0, imgW.toDouble()).toInt();
    final bottom = boundingBox.bottom.clamp(1.0, imgH.toDouble()).toInt();
    final cropW = (right - left).clamp(1, imgW);
    final cropH = (bottom - top).clamp(1, imgH);

    if (image.planes.length < 2) return null;
    final yPlane = image.planes[0].bytes;
    final uvPlane = image.planes[1].bytes;
    final uvRowStride = image.planes[1].bytesPerRow;

    final result = Float32List(targetSize * targetSize * 3);

    for (int ty = 0; ty < targetSize; ty++) {
      for (int tx = 0; tx < targetSize; tx++) {
        final sx = left + (tx * cropW / targetSize).toInt();
        final sy = top + (ty * cropH / targetSize).toInt();

        final yVal = yPlane[sy * imgW + sx] & 0xFF;
        final uvIdx = (sy ~/ 2) * uvRowStride + (sx ~/ 2) * 2;
        final vVal = uvIdx < uvPlane.length ? uvPlane[uvIdx] & 0xFF : 128;
        final uVal =
            uvIdx + 1 < uvPlane.length ? uvPlane[uvIdx + 1] & 0xFF : 128;

        final r = (yVal + 1.402 * (vVal - 128)).clamp(0.0, 255.0);
        final g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128))
            .clamp(0.0, 255.0);
        final b = (yVal + 1.772 * (uVal - 128)).clamp(0.0, 255.0);

        final idx = (ty * targetSize + tx) * 3;
        result[idx] = (r / 127.5) - 1.0;
        result[idx + 1] = (g / 127.5) - 1.0;
        result[idx + 2] = (b / 127.5) - 1.0;
      }
    }

    return result;
  }

  List<double> _l2Normalize(List<double> vec) {
    final norm = math.sqrt(vec.fold<double>(0.0, (s, v) => s + v * v));
    if (norm == 0) return vec;
    return vec.map((v) => v / norm).toList();
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

  List<double> _bytesToFloats(Uint8List bytes) {
    if (bytes.length % 4 != 0) return [];
    return bytes.buffer.asFloat32List().map((f) => f.toDouble()).toList();
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
    final already =
        await db.checkinsDao.hasCheckinForEvent(enrollee.id, _activeEventId!);
    if (already) return;

    final deviceId = await ref.read(deviceIdServiceProvider).getDeviceId();

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

  Widget _buildHintBanner(_FaceHint hint) {
    final (IconData icon, String text, Color color) = switch (hint) {
      _FaceHint.noFace => (
          Icons.face_retouching_off_outlined,
          'FACE NOT IN FRAME',
          AppColors.textMuted,
        ),
      _FaceHint.moveCloser => (
          Icons.zoom_in,
          'MOVE CLOSER',
          AppColors.blueLight,
        ),
      _FaceHint.moveBack => (
          Icons.zoom_out,
          'MOVE BACK',
          AppColors.blueLight,
        ),
      _FaceHint.centerFace => (
          Icons.center_focus_strong_outlined,
          'CENTER YOUR FACE',
          AppColors.blueLight,
        ),
      _FaceHint.lookStraight => (
          Icons.face_outlined,
          'LOOK STRAIGHT AHEAD',
          AppColors.blueLight,
        ),
      _FaceHint.none => (Icons.check, '', AppColors.success),
    };

    return Center(
      key: ValueKey(hint),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.darkBackground.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(scanCameraFacingProvider, (prev, next) {
      if (prev != next && ref.read(activeScanModeProvider) == ScanMode.face) {
        // Re-init with the new camera direction.
        _releaseCamera().then((_) {
          if (mounted && ref.read(activeScanModeProvider) == ScanMode.face) {
            _initCamera();
          }
        });
      }
    });

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
              if (mounted &&
                  ref.read(activeScanModeProvider) == ScanMode.face) {
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

          // Guidance hint banner
          if (_faceState != _FaceState.success)
            Positioned(
              bottom: 16,
              left: 24,
              right: 24,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _hint != _FaceHint.none
                    ? _buildHintBanner(_hint)
                    : const SizedBox.shrink(key: ValueKey('none')),
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
