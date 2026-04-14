import 'dart:math';

class IdGenerator {
  static int _counter = 0;
  static final Random _random = Random.secure();

  static String next() {
    _counter = (_counter + 1) % 1000000;
    final now = DateTime.now().microsecondsSinceEpoch;
    final randomPart = _random.nextInt(1 << 20);
    return '$now-$_counter-$randomPart';
  }
}
