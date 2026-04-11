import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Service for fetching road routes from OSRM (free, no API key needed)
/// and searching places via Nominatim (free, no API key needed).
class RouteService {
  RouteService._();

  // ─── OSRM: Road Route ───────────────────────────────────
  // Public OSRM server — free, no key. Note: lng,lat order (not lat,lng).
  static const _osrmBase = 'https://router.project-osrm.org/route/v1/driving';

  /// Fetches a road-following route between two points.
  /// Returns a List<LatLng> representing the route polyline,
  /// or null if the request fails.
  static Future<RouteResult?> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    // OSRM uses lng,lat order
    final url = Uri.parse(
      '$_osrmBase/$originLng,$originLat;$destLng,$destLat'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes[0] as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>?;
      if (geometry == null) return null;

      final coordinates = geometry['coordinates'] as List<dynamic>;
      // GeoJSON is [lng, lat], we need LatLng(lat, lng)
      final points = coordinates.map((coord) {
        final c = coord as List<dynamic>;
        return LatLng(c[1].toDouble(), c[0].toDouble());
      }).toList();

      // Extract distance (meters) and duration (seconds)
      final distance = (route['distance'] ?? 0).toDouble();
      final duration = (route['duration'] ?? 0).toDouble();

      return RouteResult(
        points: points,
        distanceMeters: distance,
        durationSeconds: duration,
      );
    } catch (e) {
      debugPrint('OSRM route error: $e');
      return null;
    }
  }

  // ─── NOMINATIM: Place Search ────────────────────────────
  // Free OpenStreetMap geocoding. Max 1 req/sec. No API key.
  static const _nominatimBase = 'https://nominatim.openstreetmap.org/search';

  /// Searches for places matching [query].
  /// Returns a list of PlaceResult (max 5).
  static Future<List<PlaceResult>> searchPlaces(String query) async {
    if (query.trim().length < 3) return [];

    final url = Uri.parse(
      '$_nominatimBase?q=${Uri.encodeComponent(query)}'
      '&format=json&limit=5&addressdetails=1',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'NoOneLeftBehind-FlutterApp/1.0',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as List<dynamic>;
      return data.map((item) {
        final m = item as Map<String, dynamic>;
        return PlaceResult(
          name: m['display_name']?.toString() ?? '',
          lat: double.tryParse(m['lat']?.toString() ?? '') ?? 0,
          lng: double.tryParse(m['lon']?.toString() ?? '') ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('Nominatim search error: $e');
      return [];
    }
  }

  /// Reverse geocodes a coordinate to a place name.
  static Future<String?> reverseGeocode(double lat, double lng) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=$lat&lon=$lng&format=json&zoom=16',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'NoOneLeftBehind-FlutterApp/1.0',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['display_name']?.toString();
    } catch (e) {
      debugPrint('Nominatim reverse error: $e');
      return null;
    }
  }
}

/// Result of a route calculation.
class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  /// Distance in km, formatted.
  String get distanceText {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(0)} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  /// Duration, formatted.
  String get durationText {
    final mins = (durationSeconds / 60).round();
    if (mins < 60) return '$mins min';
    final hrs = mins ~/ 60;
    final rem = mins % 60;
    return '${hrs}h ${rem}m';
  }
}

/// Result from a place search.
class PlaceResult {
  final String name;
  final double lat;
  final double lng;

  const PlaceResult({
    required this.name,
    required this.lat,
    required this.lng,
  });
}
