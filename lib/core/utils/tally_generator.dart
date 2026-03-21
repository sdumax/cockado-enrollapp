import 'dart:math';

abstract class TallyGenerator {
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Generates a random 6-character alphanumeric tally code.
  static String generate() {
    final rand = Random.secure();
    return List.generate(6, (_) => _chars[rand.nextInt(_chars.length)]).join();
  }
}
