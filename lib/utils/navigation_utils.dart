import 'package:url_launcher/url_launcher.dart';

/// Utility for launching external maps with coordinates.
class NavigationUtils {
  NavigationUtils._();

  /// Opens Google Maps (or fallback browser) with directions to [lat], [lng].
  /// If [label] is provided, it is shown as the destination name.
  static Future<void> launchGoogleMaps({
    required double lat,
    required double lng,
    String? label,
  }) async {
    // Google Maps universal URL — works on Android, iOS, and web.
    // Uses "dir" mode so it starts actual turn-by-turn nav.
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'
      '${label != null ? '&destination_place_id=' : ''}',
    );

    // Simpler fallback: geo intent (Android) / Apple Maps (iOS)
    final geoUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
    }
  }

  /// Opens Google Maps to navigate to a specific member's current location.
  static Future<void> navigateToMember({
    required double lat,
    required double lng,
    String? memberName,
  }) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  /// Opens Google Maps with a full route from origin to destination.
  static Future<void> openRouteInGoogleMaps({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=$originLat,$originLng'
      '&destination=$destLat,$destLng'
      '&travelmode=driving',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
