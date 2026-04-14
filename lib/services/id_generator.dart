import 'dart:math';

class IdGenerator {
  static final Random _random = Random.secure();

  static String next() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final randomA = _random.nextInt(1 << 30);
    final randomB = _random.nextInt(1 << 30);
    return '$now-$randomA-$randomB';
  }
}
