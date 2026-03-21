import 'package:flutter_test/flutter_test.dart';
import 'package:cockado_enrollapp/core/utils/tally_generator.dart';

void main() {
  group('TallyGenerator', () {
    test('generates 6 characters', () {
      expect(TallyGenerator.generate().length, equals(6));
    });

    test('only contains valid characters', () {
      const valid = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      for (var i = 0; i < 100; i++) {
        final tally = TallyGenerator.generate();
        for (final char in tally.split('')) {
          expect(valid.contains(char), isTrue, reason: 'Invalid char: $char');
        }
      }
    });

    test('generates unique values (probabilistic)', () {
      final values = List.generate(50, (_) => TallyGenerator.generate()).toSet();
      // With 32^6 ≈ 1B possibilities, 50 values should all be unique
      expect(values.length, equals(50));
    });
  });
}
