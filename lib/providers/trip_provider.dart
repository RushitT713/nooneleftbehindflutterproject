import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_model.dart';
import '../models/member_model.dart';
import '../services/trip_service.dart';
import '../constants.dart';

/// Result of attempting to restore a saved trip session.
enum SessionRestoreResult {
  /// Restored successfully — navigate to map.
  success,
  /// No saved session found — nothing to restore.
  noSession,
  /// Saved session found but the trip has expired or been disbanded.
  expired,
}

/// Full trip state manager — holds all current trip info, members, and
/// persists the active trip to SharedPreferences for reconnection.
class TripProvider extends ChangeNotifier {
  final TripService _tripService = TripService();

  // ── Core State ────────────────────────────
  String? _userId;
  String? _tripCode;
  String? _nickname;
  String? _vehicleType;
  String? _photoUrl;
  bool _isHost = false;
  TripModel? _tripModel;
  Map<String, MemberModel> _members = {};
  bool _isInTrip = false;
  bool _isParkingMode = false;

  // ── Stream Subscriptions ──────────────────
  StreamSubscription? _membersSubscription;
  StreamSubscription? _metadataSubscription;

  // ── Getters ───────────────────────────────
  String? get userId => _userId;
  String? get tripCode => _tripCode;
  String? get nickname => _nickname;
  String? get vehicleType => _vehicleType;
  String? get photoUrl => _photoUrl;
  bool get isHost => _isHost;
  bool get isInTrip => _isInTrip;
  bool get isParkingMode => _isParkingMode;
  TripModel? get tripModel => _tripModel;
  Map<String, MemberModel> get members => _members;
  int get memberCount => _members.length;
  int get onlineMemberCount =>
      _members.values.where((m) => m.isOnline).length;

  MemberModel? get myMember =>
      _userId != null ? _members[_userId] : null;

  // ──────────────────────────────────────────
  // SET TRIP (after create or join)
  // ──────────────────────────────────────────

  Future<void> setTrip({
    required String userId,
    required String tripCode,
    required String nickname,
    required String vehicleType,
    required String? photoUrl,
    required bool isHost,
    TripModel? tripModel,
  }) async {
    _userId = userId;
    _tripCode = tripCode;
    _nickname = nickname;
    _vehicleType = vehicleType;
    _photoUrl = photoUrl;
    _isHost = isHost;
    _tripModel = tripModel;
    _isInTrip = true;

    // Persist for reconnection
    await _saveToPrefs();

    // Start listening to member and metadata changes
    _startListening();

    notifyListeners();
  }

  // ──────────────────────────────────────────
  // CLEAR TRIP (on leave, disband, or expiry)
  // ──────────────────────────────────────────

  Future<void> clearTrip() async {
    _stopListening();

    _userId = null;
    _tripCode = null;
    _nickname = null;
    _vehicleType = null;
    _photoUrl = null;
    _isHost = false;
    _tripModel = null;
    _members = {};
    _isInTrip = false;
    _isParkingMode = false;

    await _clearPrefs();
    notifyListeners();
  }

  // ──────────────────────────────────────────
  // PARKING MODE
  // ──────────────────────────────────────────

  void toggleParkingMode() {
    _isParkingMode = !_isParkingMode;
    notifyListeners();
  }

  // ──────────────────────────────────────────
  // LISTENERS
  // ──────────────────────────────────────────

  void _startListening() {
    if (_tripCode == null) return;

    // Listen to members
    _membersSubscription = _tripService
        .listenToMembers(_tripCode!)
        .listen((membersMap) {
      _members = membersMap;
      notifyListeners();
    }, onError: (e) {
      debugPrint('TripProvider members stream error: $e');
    });

    // Listen to metadata (for status/expiry changes)
    _metadataSubscription = _tripService
        .listenToMetadata(_tripCode!)
        .listen((tripModel) {
      _tripModel = tripModel;
      if (tripModel != null) {
        if (tripModel.isExpired || tripModel.status == TripStatus.disbanded) {
          // Trip has expired or been disbanded abruptly
          clearTrip();
        }
        // If status == TripStatus.ended, we leave it active in provider.
        // The UI (MapScreen) will react to this status change, show the
        // TripSummaryDialog, and then call clearTrip() when dismissed.
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint('TripProvider metadata stream error: $e');
    });
  }

  void _stopListening() {
    _membersSubscription?.cancel();
    _metadataSubscription?.cancel();
    _membersSubscription = null;
    _metadataSubscription = null;
  }

  // ──────────────────────────────────────────
  // PERSISTENCE (SharedPreferences)
  // ──────────────────────────────────────────

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_trip_code', _tripCode ?? '');
    await prefs.setString('active_user_id', _userId ?? '');
    await prefs.setString('active_nickname', _nickname ?? '');
    await prefs.setString('active_vehicle_type', _vehicleType ?? '');
    await prefs.setString('active_photo_url', _photoUrl ?? '');
    await prefs.setBool('active_is_host', _isHost);
  }

  Future<void> _clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_trip_code');
    await prefs.remove('active_user_id');
    await prefs.remove('active_nickname');
    await prefs.remove('active_vehicle_type');
    await prefs.remove('active_photo_url');
    await prefs.remove('active_is_host');
  }

  /// Attempts to restore a previous trip session from SharedPreferences.
  /// Returns a [SessionRestoreResult] indicating the outcome.
  Future<SessionRestoreResult> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString('active_trip_code');
    final savedUid = prefs.getString('active_user_id');

    if (savedCode == null ||
        savedCode.isEmpty ||
        savedUid == null ||
        savedUid.isEmpty) {
      return SessionRestoreResult.noSession;
    }

    // Check if the trip is still alive in Firebase
    final isExpired = await _tripService.cleanupIfExpired(savedCode);
    if (isExpired) {
      await _clearPrefs();
      return SessionRestoreResult.expired;
    }

    // Restore the session
    _userId = savedUid;
    _tripCode = savedCode;
    _nickname = prefs.getString('active_nickname');
    _vehicleType = prefs.getString('active_vehicle_type');
    _photoUrl = prefs.getString('active_photo_url');
    _isHost = prefs.getBool('active_is_host') ?? false;
    _isInTrip = true;

    // Mark back online
    await _tripService.markOnline(
      tripCode: savedCode,
      userUid: savedUid,
    );

    _startListening();
    notifyListeners();
    return SessionRestoreResult.success;
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
}