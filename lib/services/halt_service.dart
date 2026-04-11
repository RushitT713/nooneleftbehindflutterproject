import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../constants.dart';
import '../models/halt_model.dart';

/// Service for all halt proposal Firebase RTDB operations.
class HaltService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Proposes a new halt stop. The proposer automatically votes 'yes'.
  Future<void> proposeHalt({
    required String tripCode,
    required String userId,
    required String userName,
    required String locationName,
    String? note,
  }) async {
    final ref = _db.child(haltsPath(tripCode)).push();
    await ref.set({
      'proposedBy': userId,
      'proposerName': userName,
      'locationName': locationName,
      'locationLat': 0.0,
      'locationLng': 0.0,
      'note': note,
      'status': HaltStatus.active.name,
      'createdAt': ServerValue.timestamp,
      'votes': {
        userId: 'yes', // auto-vote yes for proposer
      },
    });
  }

  /// Casts or updates a vote on a halt proposal.
  Future<void> vote({
    required String tripCode,
    required String haltId,
    required String userId,
    required HaltVote vote,
  }) async {
    await _db
        .child(haltPath(tripCode, haltId))
        .child('votes')
        .child(userId)
        .set(vote.name);
  }

  /// Removes a user's vote (toggle off).
  Future<void> removeVote({
    required String tripCode,
    required String haltId,
    required String userId,
  }) async {
    await _db
        .child(haltPath(tripCode, haltId))
        .child('votes')
        .child(userId)
        .remove();
  }

  /// Resolves a halt proposal (convoy agreed to stop).
  Future<void> resolveHalt({
    required String tripCode,
    required String haltId,
  }) async {
    await _db.child(haltPath(tripCode, haltId)).update({
      'status': HaltStatus.resolved.name,
    });
  }

  /// Cancels a halt proposal.
  Future<void> cancelHalt({
    required String tripCode,
    required String haltId,
  }) async {
    await _db.child(haltPath(tripCode, haltId)).update({
      'status': HaltStatus.cancelled.name,
    });
  }

  /// Listens to all active halt proposals in real-time.
  /// Returns proposals sorted by createdAt (newest first).
  Stream<List<HaltModel>> listenToHalts(String tripCode) {
    return _db.child(haltsPath(tripCode)).onValue.map((event) {
      final val = event.snapshot.value;
      if (val is! Map<dynamic, dynamic>) {
        return <HaltModel>[];
      }

      final halts = <HaltModel>[];
      val.forEach((key, value) {
        if (value is Map) {
          halts.add(
            HaltModel.fromMap(
              key.toString(),
              Map<dynamic, dynamic>.from(value),
            ),
          );
        }
      });

      final activeHalts = halts.where((h) => h.status == HaltStatus.active).toList();

      // Sort newest first
      activeHalts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return activeHalts;
    });
  }
}
