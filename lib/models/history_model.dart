/// Model for a completed trip history entry.
library;

class TripHistoryModel {
  final String id;
  final String tripCode;
  final String? destinationName;
  final int timestamp; // Also known as createdAt
  final int durationSeconds;
  final int memberCount;
  final bool wasHost;
  final String vehicleType;
  final List<String> memberNames;
  final int endedAt;

  TripHistoryModel({
    required this.id,
    required this.tripCode,
    this.destinationName,
    required this.timestamp,
    required this.durationSeconds,
    required this.memberCount,
    this.wasHost = false,
    this.vehicleType = 'Car',
    this.memberNames = const [],
    this.endedAt = 0,
  });

  factory TripHistoryModel.fromMap(String id, Map<dynamic, dynamic> data) {
    return TripHistoryModel(
      id: id,
      tripCode: data['tripCode']?.toString() ?? 'Unknown',
      destinationName: data['destinationName']?.toString(),
      timestamp: data['timestamp'] ?? 0,
      durationSeconds: data['durationSeconds'] ?? 0,
      memberCount: data['memberCount'] ?? 1,
      wasHost: data['wasHost'] ?? false,
      vehicleType: data['vehicleType']?.toString() ?? 'Car',
      memberNames: (data['memberNames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      endedAt: data['endedAt'] ?? data['timestamp'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tripCode': tripCode,
      'destinationName': destinationName,
      'timestamp': timestamp,
      'durationSeconds': durationSeconds,
      'memberCount': memberCount,
      'wasHost': wasHost,
      'vehicleType': vehicleType,
      'memberNames': memberNames,
      'endedAt': endedAt,
    };
  }
}
