import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:cockado_enrollapp/core/utils/face_utils.dart';

void main() {
  group('FaceUtils.cosineSimilarity', () {
    test('identical vectors → 1.0', () {
      final v = Float32List.fromList(List.generate(512, (i) => i * 0.001));
      expect(FaceUtils.cosineSimilarity(v, v), closeTo(1.0, 1e-5));
    });

    test('opposite vectors → -1.0', () {
      final a = Float32List.fromList(List.generate(512, (_) => 1.0));
      final b = Float32List.fromList(List.generate(512, (_) => -1.0));
      expect(FaceUtils.cosineSimilarity(a, b), closeTo(-1.0, 1e-5));
    });

    test('orthogonal vectors → 0.0', () {
      final a = Float32List(512);
      final b = Float32List(512);
      a[0] = 1.0;
      b[1] = 1.0;
      expect(FaceUtils.cosineSimilarity(a, b), closeTo(0.0, 1e-5));
    });

    test('above threshold means match', () {
      final v = Float32List.fromList(List.generate(512, (i) => i * 0.001));
      final score = FaceUtils.cosineSimilarity(v, v);
      expect(score >= FaceUtils.matchThreshold, isTrue);
    });
  });

  group('FaceUtils embedding serialisation', () {
    test('round-trip bytes → Float32List → bytes', () {
      final original = Float32List.fromList(List.generate(512, (i) => i * 0.1));
      final bytes = FaceUtils.embeddingToBytes(original);
      final restored = FaceUtils.bytesToEmbedding(bytes);
      expect(restored.length, equals(original.length));
      for (var i = 0; i < original.length; i++) {
        expect(restored[i], closeTo(original[i], 1e-6));
      }
    });
  });
}
