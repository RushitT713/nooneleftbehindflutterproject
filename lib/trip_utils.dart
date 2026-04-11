import 'dart:math';

class TripUtils {
  // We exclude O, 0, I, 1 to prevent user error during entry
  static const String _charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

  static String generateTripCode() {
    final Random random = Random();
    return List.generate(6, (index) => _charset[random.nextInt(_charset.length)]).join();
  }
}