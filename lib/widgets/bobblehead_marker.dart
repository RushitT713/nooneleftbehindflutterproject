import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants.dart';

/// Extracted bobblehead marker widget for convoy members on the map.
/// Handles vehicle rotation, profile photo or initials circle, and info badge.
class BobbleheadMarker extends StatelessWidget {
  final String nickname;
  final String photoUrl;
  final String vehicleType;
  final double headingRadians;
  final bool isMe;
  final String distanceText;
  final String? compassDirection;

  const BobbleheadMarker({
    super.key,
    required this.nickname,
    required this.photoUrl,
    required this.vehicleType,
    required this.headingRadians,
    required this.isMe,
    required this.distanceText,
    this.compassDirection,
  });

  /// Generate initials from nickname (up to 2 chars).
  String get _initials {
    final parts = nickname.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nickname.isNotEmpty ? nickname[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final vehicleName = vehicleType.toLowerCase();

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // 1. Glow effect for current user
        if (isMe)
          Positioned(
            bottom: 20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kPrimary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          ),

        // 2. The Rotating Vehicle
        Positioned(
          left: 26,
          bottom: 13,
          child: Transform.rotate(
            angle: headingRadians,
            child: Image.asset(
              'assets/images/$vehicleName.png',
              width: 80,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.directions_car, size: 60, color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary)),
            ),
          ),
        ),

        // 3. Floating Head — photo or initials circle
        Positioned(
          bottom: 50,
          child: photoUrl.isNotEmpty
              ? Image.network(
                  photoUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildInitialsCircle(),
                )
              : _buildInitialsCircle(),
        ),

        // 4. Info Badge (Nickname + Distance + Compass)
        Positioned(
          bottom: -5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isMe
                  ? kPrimary
                  : Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isMe ? kPrimaryDark : (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMe ? 'You' : nickname,
                  style: TextStyle(
                    color: isMe ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (distanceText.isNotEmpty && !isMe)
                  Text(
                    compassDirection != null
                        ? '$distanceText · $compassDirection'
                        : distanceText,
                    style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary), fontSize: 9),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Fallback initials avatar when no photo is available.
  Widget _buildInitialsCircle() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isMe ? kAccentBlue : kPrimary,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}

// ── Compass Direction Helper ─────────────────────────

/// Calculate compass direction from one point to another.
/// Returns a string like "N", "NE", "SW", etc.
String compassDirection(double fromLat, double fromLng, double toLat, double toLng) {
  final dLng = _toRadians(toLng - fromLng);
  final fromLatR = _toRadians(fromLat);
  final toLatR = _toRadians(toLat);

  final y = math.sin(dLng) * math.cos(toLatR);
  final x = math.cos(fromLatR) * math.sin(toLatR) -
      math.sin(fromLatR) * math.cos(toLatR) * math.cos(dLng);

  var bearing = math.atan2(y, x) * 180 / math.pi;
  bearing = (bearing + 360) % 360;

  const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final index = ((bearing + 22.5) / 45).floor() % 8;
  return directions[index];
}

double _toRadians(double degree) => degree * math.pi / 180.0;
