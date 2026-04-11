import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../constants.dart';
import '../models/sos_model.dart';

/// Service for all SOS Firebase RTDB operations.
class SosService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Triggers a new SOS alert for the convoy.
  Future<String> triggerSos({
    required String tripCode,
    required String userId,
    required String userName,
    required SosReason reason,
    String? note,
    required double lat,
    required double lng,
  }) async {
    final ref = _db.child(sosPath(tripCode)).push();
    await ref.set({
      'triggeredBy': userId,
      'triggerName': userName,
      'reason': reason.name,
      'note': note,
      'lat': lat,
      'lng': lng,
      'acknowledgedBy': {},
      'resolvedAt': null,
      'createdAt': ServerValue.timestamp,
    });
    return ref.key!;
  }

  /// Acknowledges an active SOS (indicates you saw the alert).
  Future<void> acknowledgeSos({
    required String tripCode,
    required String sosId,
    required String userId,
  }) async {
    await _db
        .child(sosPath(tripCode))
        .child(sosId)
        .child('acknowledgedBy')
        .child(userId)
        .set(true);
  }

  /// Resolves an active SOS (emergency is over).
  Future<void> resolveSos({
    required String tripCode,
    required String sosId,
  }) async {
    await _db.child(sosPath(tripCode)).child(sosId).update({
      'resolvedAt': ServerValue.timestamp,
    });
  }

  /// Listens to the most recent active (unresolved) SOS.
  /// Returns null if no active SOS exists.
  Stream<SosModel?> listenToActiveSos(String tripCode) {
    return _db
        .child(sosPath(tripCode))
        .orderByChild('createdAt')
        .limitToLast(10)
        .onValue
        .map((event) {
      final val = event.snapshot.value;
      if (val is! Map<dynamic, dynamic>) {
        return null;
      }

      // Find the most recent unresolved SOS among the last 10
      SosModel? activeSos;
      int latestTimestamp = 0;

      val.forEach((key, value) {
        if (value is Map) {
          final map = Map<dynamic, dynamic>.from(value);
          if (map['resolvedAt'] == null) {
            final createdAt =
                map['createdAt'] is int ? map['createdAt'] as int : 0;
            if (createdAt >= latestTimestamp) {
              latestTimestamp = createdAt;
              activeSos = SosModel.fromMap(key.toString(), map);
            }
          }
        }
      });

      return activeSos;
    });
  }

  /// Listens to a specific SOS by ID.
  Stream<SosModel?> listenToSos(String tripCode, String sosId) {
    return _db
        .child(sosPath(tripCode))
        .child(sosId)
        .onValue
        .map((event) {
      final val = event.snapshot.value;
      if (val is! Map<dynamic, dynamic>) {
        return null;
      }
      return SosModel.fromMap(sosId, val);
    });
  }
}
