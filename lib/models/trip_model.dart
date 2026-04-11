import '../constants.dart';

/// A convoy destination set by the host.
class TripDestination {
  final String name;
  final double lat;
  final double lng;

  const TripDestination({
    required this.name,
    required this.lat,
    required this.lng,
  });

  factory TripDestination.fromMap(Map<dynamic, dynamic> map) {
    return TripDestination(
      name: map['name']?.toString() ?? 'Destination',
      lat: (map['lat'] ?? 0).toDouble(),
      lng: (map['lng'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'lat': lat,
        'lng': lng,
      };
}

class TripModel {
  final String tripCode;
  final String hostId;
  final int createdAt;
  final String durationKey; // 'quick', 'halfDay', 'dayTrip', 'multiDay'
  final int expiresAt;
  final TripStatus status;
  final TripDestination? destination;

  TripModel({
    required this.tripCode,
    required this.hostId,
    required this.createdAt,
    required this.durationKey,
    required this.expiresAt,
    required this.status,
    this.destination,
  });

  TripDuration get tripDuration {
    switch (durationKey) {
      case 'quick':
        return TripDuration.quick;
      case 'halfDay':
        return TripDuration.halfDay;
      case 'dayTrip':
        return TripDuration.dayTrip;
      case 'multiDay':
        return TripDuration.multiDay;
      default:
        return TripDuration.quick;
    }
  }

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch > expiresAt ||
      status != TripStatus.active;

  Duration get remainingTime {
    final now = DateTime.now().millisecondsSinceEpoch;
    final remaining = expiresAt - now;
    return remaining > 0 ? Duration(milliseconds: remaining) : Duration.zero;
  }

  factory TripModel.fromMap(String code, Map<dynamic, dynamic> map) {
    TripDestination? dest;
    final destData = map['destination'];
    if (destData is Map<dynamic, dynamic>) {
      dest = TripDestination.fromMap(destData);
    }

    return TripModel(
      tripCode: code,
      hostId: map['hostId']?.toString() ?? '',
      createdAt: (map['createdAt'] ?? 0) is int
          ? map['createdAt'] as int
          : 0,
      durationKey: map['durationKey']?.toString() ?? 'quick',
      expiresAt: (map['expiresAt'] ?? 0) is int
          ? map['expiresAt'] as int
          : 0,
      status: TripStatus.fromString(map['status']?.toString()),
      destination: dest,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'createdAt': createdAt,
      'durationKey': durationKey,
      'expiresAt': expiresAt,
      'status': status.name,
      if (destination != null) 'destination': destination!.toMap(),
    };
  }
}
