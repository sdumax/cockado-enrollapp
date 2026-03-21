import 'dart:math' as math;
import 'dart:typed_data';

abstract class FaceUtils {
  /// Compute cosine similarity between two 512-float embedding vectors.
  /// Returns a value between -1.0 and 1.0. Match threshold: >= 0.75.
  static double cosineSimilarity(Float32List a, Float32List b) {
    assert(a.length == b.length, 'Embedding length mismatch');
    double dot = 0, normA = 0, normB = 0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = math.sqrt(normA) * math.sqrt(normB);
    return denom == 0 ? 0 : dot / denom;
  }

  static const double matchThreshold = 0.75;

  /// Converts a Float32List embedding to raw bytes for DB storage.
  static Uint8List embeddingToBytes(Float32List embedding) {
    return embedding.buffer.asUint8List();
  }

  /// Converts raw bytes (from DB) back to a Float32List embedding.
  static Float32List bytesToEmbedding(Uint8List bytes) {
    return bytes.buffer.asFloat32List();
  }
}
