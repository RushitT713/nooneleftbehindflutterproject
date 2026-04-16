import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../constants.dart';
import '../models/trip_model.dart';
import '../models/member_model.dart';
import '../trip_utils.dart';

/// Central service for all Firebase RTDB trip operations.
class TripService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ──────────────────────────────────────────
  // CREATE TRIP
  // ──────────────────────────────────────────

  /// Creates a new trip and returns the generated trip code.
  Future<String> createTrip({
    required String hostUid,
    required String nickname,
    required String vehicleType,
    required String? photoUrl,
    required TripDuration duration,
  }) async {
    String tripCode = TripUtils.generateTripCode();

    // Ensure code is unique (extremely rare collision, but safety first)
    // Using .once() instead of .get() to avoid firebase_database plugin bug
    // where .get() crashes in platformExceptionToFirebaseException
    try {
      DatabaseEvent event = await _db.child(tripPath(tripCode)).once();
      int retries = 0;
      while (event.snapshot.exists && retries < 5) {
        tripCode = TripUtils.generateTripCode();
        event = await _db.child(tripPath(tripCode)).once();
        retries++;
      }
    } catch (e) {
      // If uniqueness check fails, proceed anyway — collision is extremely rare
      // (31^6 = ~887 million possible codes)
      debugPrint('Uniqueness check failed, proceeding: $e');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = now + duration.duration.inMilliseconds;

    await _db.child(tripPath(tripCode)).set({
      'metadata': {
        'hostId': hostUid,
        'createdAt': ServerValue.timestamp,
        'durationKey': duration.name,
        'expiresAt': expiresAt,
        'status': TripStatus.active.name,
      },
      'members': {
        hostUid: {
          'nickname': nickname,
          'vehicleType': vehicleType,
          'photoUrl': photoUrl,
          'isOnline': true,
          'joinedAt': ServerValue.timestamp,
          'role': MemberRole.host.name,
        }
      }
    });

    // Set up disconnect handler for the host
    _setupDisconnectHandler(tripCode, hostUid);

    return tripCode;
  }

  // ──────────────────────────────────────────
  // JOIN TRIP
  // ──────────────────────────────────────────

  /// Validates and joins an existing trip. Throws on failure.
  Future<TripModel> joinTrip({
    required String tripCode,
    required String userUid,
    required String nickname,
    required String vehicleType,
    required String? photoUrl,
  }) async {
    final event = await _db.child(tripPath(tripCode)).once();
    final snapshot = event.snapshot;

    if (!snapshot.exists) {
      throw 'Trip code not found. Please check with your host.';
    }

    final val = snapshot.value;
    if (val is! Map<dynamic, dynamic>) {
      throw 'Trip data is corrupted.';
    }
    final tripData = val;
    final metadataVal = tripData['metadata'];
    if (metadataVal is! Map<dynamic, dynamic>) {
      throw 'Trip data is corrupted.';
    }
    final metadata = metadataVal;

    final status = TripStatus.fromString(metadata['status']?.toString());
    if (status != TripStatus.active) {
      throw 'This trip has already ended.';
    }

    // Check expiry
    final expiresAt = metadata['expiresAt'] is int
        ? metadata['expiresAt'] as int
        : 0;
    if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
      throw 'This trip has expired.';
    }

    // Check member count
    final members = tripData['members'];
    if (members is Map<dynamic, dynamic> && members.length >= kMaxConvoyMembers) {
      throw 'Convoy is full! (Max $kMaxConvoyMembers vehicles)';
    }

    // Add the member
    await _db.child(memberPath(tripCode, userUid)).set({
      'nickname': nickname,
      'vehicleType': vehicleType,
      'photoUrl': photoUrl,
      'isOnline': true,
      'joinedAt': ServerValue.timestamp,
      'role': MemberRole.member.name,
    });

    // Set up disconnect handler
    _setupDisconnectHandler(tripCode, userUid);

    return TripModel.fromMap(tripCode, metadata);
  }

  // ──────────────────────────────────────────
  // TRIP INFO
  // ──────────────────────────────────────────

  /// Fetches trip metadata once.
  Future<TripModel?> getTripInfo(String tripCode) async {
    final event = await _db.child(metadataPath(tripCode)).once();
    final snapshot = event.snapshot;
    if (!snapshot.exists) return null;
    final val = snapshot.value;
    if (val is! Map<dynamic, dynamic>) return null;
    return TripModel.fromMap(tripCode, val);
  }

  /// Checks if a trip exists and is active.
  Future<bool> isTripActive(String tripCode) async {
    final trip = await getTripInfo(tripCode);
    if (trip == null) return false;
    return !trip.isExpired;
  }

  // ──────────────────────────────────────────
  // LEAVE / DISBAND
  // ──────────────────────────────────────────

  /// Non-host member leaves the trip.
  Future<void> leaveTrip({
    required String tripCode,
    required String userUid,
  }) async {
    // Remove member details and live location entirely from the convoy
    await _db.child(memberPath(tripCode, userUid)).remove();
    await _db.child(liveLocationPath(tripCode, userUid)).remove();
  }

  /// Host formally ends the trip.
  /// This calculates stats, saves history for all members, 
  /// and sets status to 'ended'.
  Future<void> endTrip({required String tripCode}) async {
    try {
      final metadataEvent = await _db.child(metadataPath(tripCode)).once();
      final membersEvent = await _db.child(membersPath(tripCode)).once();

      if (metadataEvent.snapshot.exists && membersEvent.snapshot.exists) {
        final meta = metadataEvent.snapshot.value as Map<dynamic, dynamic>;
        final members = membersEvent.snapshot.value as Map<dynamic, dynamic>;
        
        final createdAt = meta['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch;
        final durationSecs = (DateTime.now().millisecondsSinceEpoch - createdAt) ~/ 1000;
        final dest = meta['destination'] as Map<dynamic, dynamic>?;
        final destName = dest?['name']?.toString();
        final endedAt = DateTime.now().millisecondsSinceEpoch;

        final memberNames = members.values
            .map((m) => m['nickname']?.toString() ?? 'Unknown')
            .toList();

        final updates = <String, dynamic>{};
        for (final uid in members.keys) {
          final mData = members[uid] as Map<dynamic, dynamic>? ?? {};
          final isHost = mData['role']?.toString() == MemberRole.host.name;
          final vehicleType = mData['vehicleType']?.toString() ?? 'Car';

          final historyData = {
            'tripCode': tripCode,
            'destinationName': destName,
            'timestamp': createdAt,
            'durationSeconds': durationSecs,
            'memberCount': members.length,
            'wasHost': isHost,
            'vehicleType': vehicleType,
            'memberNames': memberNames,
            'endedAt': endedAt,
          };

          final newId = _db.child('users/$uid/history').push().key;
          if (newId != null) {
            updates['users/$uid/history/$newId'] = historyData;
          }
        }
        
        // Mark trip as ended
        updates['${metadataPath(tripCode)}/status'] = TripStatus.ended.name;
        updates['${metadataPath(tripCode)}/endedAt'] = ServerValue.timestamp;
        
        if (updates.isNotEmpty) {
          await _db.update(updates);
        }
      }
    } catch (e) {
      debugPrint('Error saving trip history during endTrip: $e');
    }
  }

  /// Host disbands the trip (Legacy/Emergency delete).
  /// If [deleteImmediately] is true, all data is removed.
  /// Otherwise, status is set to 'disbanded' and data stays.
  Future<void> disbandTrip({
    required String tripCode,
    required bool deleteImmediately,
  }) async {
    // Proceed with DB cleanup
    if (deleteImmediately) {
      await _db.child(tripPath(tripCode)).remove();
    } else {
      await _db.child(metadataPath(tripCode)).update({
        'status': TripStatus.disbanded.name,
        'disbandedAt': ServerValue.timestamp,
      });
      // Remove live locations immediately
      await _db.child(liveLocationsPath(tripCode)).remove();
    }
  }

  // ──────────────────────────────────────────
  // HOST MANAGEMENT
  // ──────────────────────────────────────────

  /// Kicks a member from the trip.
  Future<void> kickMember({
    required String tripCode,
    required String targetUid,
  }) async {
    await _db.child(memberPath(tripCode, targetUid)).remove();
    await _db.child(liveLocationPath(tripCode, targetUid)).remove();
  }

  /// Transfers host role to another member.
  Future<void> transferHost({
    required String tripCode,
    required String currentHostUid,
    required String newHostUid,
  }) async {
    final updates = <String, dynamic>{
      '${metadataPath(tripCode)}/hostId': newHostUid,
      '${memberPath(tripCode, currentHostUid)}/role': MemberRole.member.name,
      '${memberPath(tripCode, newHostUid)}/role': MemberRole.host.name,
    };
    await _db.update(updates);
  }

  // ──────────────────────────────────────────
  // DISCONNECT HANDLER
  // ──────────────────────────────────────────

  /// Sets up Firebase `.onDisconnect()` to mark the user offline
  /// when the connection drops (app killed, network lost, etc.).
  void _setupDisconnectHandler(String tripCode, String userUid) {
    _db.child(memberPath(tripCode, userUid)).child('isOnline')
        .onDisconnect()
        .set(false);
  }

  /// Re-marks the user as online (call on reconnect/app resume).
  Future<void> markOnline({
    required String tripCode,
    required String userUid,
  }) async {
    await _db.child(memberPath(tripCode, userUid)).update({
      'isOnline': true,
    });
    _setupDisconnectHandler(tripCode, userUid);
  }

  // ──────────────────────────────────────────
  // LISTENERS (Streams)
  // ──────────────────────────────────────────

  /// Listens to all member changes in a trip.
  Stream<Map<String, MemberModel>> listenToMembers(String tripCode) {
    return _db.child(membersPath(tripCode)).onValue.map((event) {
      final val = event.snapshot.value;
      if (val is! Map<dynamic, dynamic>) {
        return <String, MemberModel>{}; // safe fallback
      }
      
      final members = <String, MemberModel>{};
      val.forEach((key, value) {
        if (value is Map<dynamic, dynamic>) {
          members[key.toString()] = MemberModel.fromMap(key.toString(), value);
        }
      });
      return members;
    });
  }

  /// Listens to all live location updates.
  Stream<Map<String, Map<String, dynamic>>> listenToLocations(String tripCode) {
    return _db.child(liveLocationsPath(tripCode)).onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return <String, Map<String, dynamic>>{};
      return data.map((key, value) => MapEntry(
        key.toString(),
        Map<String, dynamic>.from(value as Map),
      ));
    });
  }

  /// Listens to trip metadata changes (status, expiry, etc.).
  Stream<TripModel?> listenToMetadata(String tripCode) {
    return _db.child(metadataPath(tripCode)).onValue.map((event) {
      final val = event.snapshot.value;
      if (val is! Map<dynamic, dynamic>) {
        return null;
      }
      return TripModel.fromMap(tripCode, val);
    });
  }

  // ──────────────────────────────────────────
  // CLIENT-SIDE CLEANUP
  // ──────────────────────────────────────────

  /// Cleans up stale/expired trips.
  /// Call on app start. Checks if the stored trip is still valid.
  Future<bool> cleanupIfExpired(String tripCode) async {
    final trip = await getTripInfo(tripCode);
    if (trip == null) return true; // already deleted

    if (trip.isExpired) {
      // If expired or disbanded, clean up live data
      await _db.child(liveLocationsPath(tripCode)).remove();
      // If it's been more than 7 days since disbandment, delete everything
      if (trip.status == TripStatus.disbanded) {
        final disbandedEvent = await _db.child(metadataPath(tripCode)).child('disbandedAt').once();
        final disbandedSnapshot = disbandedEvent.snapshot;
        if (disbandedSnapshot.exists) {
          final disbandedAt = disbandedSnapshot.value as int;
          final sevenDaysAgo = DateTime.now().millisecondsSinceEpoch -
              const Duration(days: 7).inMilliseconds;
          if (disbandedAt < sevenDaysAgo) {
            await _db.child(tripPath(tripCode)).remove();
          }
        }
      }
      return true; // trip is expired
    }
    return false; // trip is still active
  }

  // ──────────────────────────────────────────
  // DESTINATION (Host Route)
  // ──────────────────────────────────────────

  /// Sets a shared destination for the convoy (Host only).
  Future<void> setDestination({
    required String tripCode,
    required String name,
    required double lat,
    required double lng,
  }) async {
    await _db.child(metadataPath(tripCode)).child('destination').set({
      'name': name,
      'lat': lat,
      'lng': lng,
    });
  }

  /// Clears the convoy destination.
  Future<void> clearDestination(String tripCode) async {
    await _db.child(metadataPath(tripCode)).child('destination').remove();
  }
}
