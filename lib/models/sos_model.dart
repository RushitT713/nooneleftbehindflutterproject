import '../constants.dart';

class SosModel {
  final String sosId;
  final String triggeredBy;
  final String triggerName;
  final SosReason reason;
  final String? note;
  final double lat;
  final double lng;
  final List<String> acknowledgedBy;
  final int? resolvedAt;
  final int createdAt;

  SosModel({
    required this.sosId,
    required this.triggeredBy,
    required this.triggerName,
    required this.reason,
    this.note,
    required this.lat,
    required this.lng,
    this.acknowledgedBy = const [],
    this.resolvedAt,
    required this.createdAt,
  });

  bool get isResolved => resolvedAt != null;

  bool isAcknowledgedBy(String uid) => acknowledgedBy.contains(uid);

  factory SosModel.fromMap(String id, Map<dynamic, dynamic> map) {
    final rawAck = map['acknowledgedBy'];
    final ackList = <String>[];
    if (rawAck is Map) {
      ackList.addAll(rawAck.keys.map((k) => k.toString()));
    } else if (rawAck is List) {
      ackList.addAll(rawAck.map((e) => e.toString()));
    }

    // Parse reason string back to enum
    SosReason parsedReason = SosReason.other;
    final reasonStr = map['reason']?.toString();
    if (reasonStr != null) {
      parsedReason = SosReason.values.firstWhere(
        (r) => r.name == reasonStr,
        orElse: () => SosReason.other,
      );
    }

    return SosModel(
      sosId: id,
      triggeredBy: map['triggeredBy']?.toString() ?? '',
      triggerName: map['triggerName']?.toString() ?? 'Unknown',
      reason: parsedReason,
      note: map['note']?.toString(),
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      acknowledgedBy: ackList,
      resolvedAt: map['resolvedAt'] is int ? map['resolvedAt'] as int : null,
      createdAt: map['createdAt'] is int ? map['createdAt'] as int : 0,
    );
  }

  Map<String, dynamic> toMap() {
    final ackMap = <String, bool>{};
    for (final uid in acknowledgedBy) {
      ackMap[uid] = true;
    }

    return {
      'triggeredBy': triggeredBy,
      'triggerName': triggerName,
      'reason': reason.name,
      'note': note,
      'lat': lat,
      'lng': lng,
      'acknowledgedBy': ackMap,
      'resolvedAt': resolvedAt,
      'createdAt': createdAt,
    };
  }
}
