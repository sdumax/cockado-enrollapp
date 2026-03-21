import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/mode_tabs.dart';

/// Shared provider that drives which scan sub-screen is visible.
///
/// [ScanScreen] watches this value to control the [IndexedStack] index.
/// Sub-screens ([TicketScanScreen], [FaceCaptureScreen], [TouchScreen])
/// write to it when the user taps a [ModeTabs] item.
final activeScanModeProvider =
    StateProvider<ScanMode>((ref) => ScanMode.ticket);

/// Whether any capture screen is actively processing (scanning a face,
/// reading a barcode, or reading a fingerprint).  When `true` the
/// inactivity timer in [ScanScreen] must NOT navigate to standby.
final captureActiveProvider = StateProvider<bool>((ref) => false);

/// Which camera the ticket scanner uses. Values: 'REAR' | 'FRONT'.
/// Persisted in SharedPreferences under 'pref_camera_facing'.
final scanCameraFacingProvider = StateProvider<String>((ref) => 'REAR');

/// When `true` a foreground sub-screen (Settings, Enrolment) is active and
/// the [ScanScreen] inactivity timer must NOT navigate to standby.
final standbyInhibitedProvider = StateProvider<bool>((ref) => false);
