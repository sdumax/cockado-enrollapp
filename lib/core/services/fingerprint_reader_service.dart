import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FingerprintReaderState { idle, reading, success, error }

class FingerprintReadResult {
  const FingerprintReadResult({required this.enrolleeId, this.errorMessage});
  final String? enrolleeId; // null = no match / error
  final String? errorMessage;
}

abstract class FingerprintReaderService {
  /// Stream of state changes from the reader hardware.
  Stream<FingerprintReaderState> get stateStream;

  /// Start listening for a fingerprint scan.
  Future<void> startReading();

  /// Stop / cancel an in-progress scan.
  Future<void> stopReading();

  /// Result stream — emits when a scan completes (match or no-match).
  Stream<FingerprintReadResult> get resultStream;

  /// Whether a physical reader is connected.
  bool get isConnected;

  /// Dispose resources.
  void dispose();
}

/// No-op stub — always reports "not connected".
/// Replaced by a real vendor SDK implementation later.
class NoOpFingerprintReaderService implements FingerprintReaderService {
  @override
  Stream<FingerprintReaderState> get stateStream => const Stream.empty();

  @override
  Future<void> startReading() async {}

  @override
  Future<void> stopReading() async {}

  @override
  Stream<FingerprintReadResult> get resultStream => const Stream.empty();

  @override
  bool get isConnected => false;

  @override
  void dispose() {}
}

final fingerprintReaderServiceProvider = Provider<FingerprintReaderService>((ref) {
  return NoOpFingerprintReaderService();
});
