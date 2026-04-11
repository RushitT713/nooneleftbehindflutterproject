import 'dart:async';
import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../firebase_options.dart';
import '../constants.dart';

// ─────────────────────────────────────────────────
// TOP-LEVEL CALLBACK — must be top-level or static
// ─────────────────────────────────────────────────
@pragma('vm:entry-point')
void startLocationCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

// ─────────────────────────────────────────────────
// TASK HANDLER — runs in a separate isolate
// ─────────────────────────────────────────────────
class LocationTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _positionStream;
  DateTime _lastUploadTime = DateTime.now().subtract(const Duration(minutes: 5));

  String? _tripCode;
  String? _userId;
  bool _parkingMode = false;
  bool _isLowBattery = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Initialize Firebase in this isolate — required for RTDB access
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // We use the Geolocator stream rather than repeat events,
    // so this is intentionally empty.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _positionStream?.cancel();
    _positionStream = null;
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map<String, dynamic>) {
      final action = data['action']?.toString();

      if (action == 'start') {
        _tripCode = data['tripCode']?.toString();
        _userId = data['userId']?.toString();
        _parkingMode = data['parkingMode'] == true;
        _startGpsStream();
      } else if (action == 'toggleParking') {
        _parkingMode = data['parkingMode'] == true;
        // Restart the stream with new parameters
        _positionStream?.cancel();
        _startGpsStream();
        FlutterForegroundTask.updateService(
          notificationText: _parkingMode
              ? 'Trip $_tripCode · Parking Mode 🅿️'
              : 'Trip $_tripCode · Tracking ON 📍',
        );
      } else if (action == 'updateBattery') {
        _isLowBattery = data['isLowBattery'] == true;
      } else if (action == 'stop') {
        _positionStream?.cancel();
        _positionStream = null;
      }
    }
  }

  void _startGpsStream() {
    if (_tripCode == null || _userId == null) return;

    final locationSettings = LocationSettings(
      accuracy: _parkingMode ? LocationAccuracy.low : LocationAccuracy.high,
      distanceFilter: _parkingMode ? 50 : 0,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      _processAndUpload(position);
    });
  }

  void _processAndUpload(Position position) {
    if (_tripCode == null || _userId == null) return;

    double speedKmH = position.speed * 3.6;

    // Adaptive upload interval
    int uploadIntervalSeconds;
    if (_parkingMode) {
      uploadIntervalSeconds = kParkingInterval; // 5 minutes
    } else if (speedKmH > kMovingSpeedThreshold) {
      uploadIntervalSeconds = kHighAccuracyInterval; // 3s
    } else if (speedKmH > kSlowSpeedThreshold) {
      uploadIntervalSeconds = kMediumInterval; // 10s
    } else {
      uploadIntervalSeconds = kLowInterval; // 60s
    }

    // Battery Throttling: If battery is low (< 20%), 
    // force minimum upload interval to 60 seconds (unless in parking mode which is slower)
    if (_isLowBattery && !_parkingMode && uploadIntervalSeconds < 60) {
      uploadIntervalSeconds = 60;
    }

    DateTime now = DateTime.now();
    if (now.difference(_lastUploadTime).inSeconds >= uploadIntervalSeconds) {
      _lastUploadTime = now;
      _pushToFirebase(position, speedKmH);

      // Send speed data back to the main UI
      FlutterForegroundTask.sendDataToMain({
        'lat': position.latitude,
        'lng': position.longitude,
        'speed': double.parse(speedKmH.toStringAsFixed(1)),
        'heading': double.parse(position.heading.toStringAsFixed(1)),
      });
    }
  }

  Future<void> _pushToFirebase(Position pos, double speedKmH) async {
    final ref = FirebaseDatabase.instance
        .ref(liveLocationPath(_tripCode!, _userId!));

    await ref.set({
      'lat': pos.latitude,
      'lng': pos.longitude,
      'speed': double.parse(speedKmH.toStringAsFixed(1)),
      'heading': double.parse(pos.heading.toStringAsFixed(1)),
      'accuracy': double.parse(pos.accuracy.toStringAsFixed(1)),
      'ts': ServerValue.timestamp,
    });
  }

  @override
  void onNotificationButtonPressed(String id) {
    // Handle notification button presses if needed
  }

  @override
  void onNotificationPressed() {
    // Opens the app when notification is tapped — handled by the framework
  }

  @override
  void onNotificationDismissed() {
    // No-op: foreground notification can't be dismissed on Android
  }
}

// ─────────────────────────────────────────────────
// LOCATION SERVICE — main isolate interface
// ─────────────────────────────────────────────────
class LocationService {
  /// Request location permissions.
  static Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  /// Request notification permission (Android 13+).
  static Future<void> requestNotificationPermission() async {
    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  /// Initialize the foreground service configuration.
  static void initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'convoy_tracking',
        channelName: 'Convoy Tracking',
        channelDescription: 'Tracks your location for the convoy trip.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // We don't use repeatEvent (GPS stream handles timing)
        // Set a long interval so it doesn't waste CPU
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start the foreground service and begin tracking.
  /// Returns true if tracking started successfully.
  static Future<bool> startTracking({
    required String tripCode,
    required String userId,
    bool parkingMode = false,
  }) async {
    // Request permissions
    final hasLocation = await requestPermission();
    if (!hasLocation) return false;

    if (Platform.isAndroid) {
      await requestNotificationPermission();
      if (!await Permission.ignoreBatteryOptimizations.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }

    // Initialize the service
    initService();

    ServiceRequestResult result;
    if (await FlutterForegroundTask.isRunningService) {
      result = await FlutterForegroundTask.restartService();
    } else {
      result = await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'NoOneLeftBehind',
        notificationText: 'Trip $tripCode · Tracking ON 📍',
        notificationInitialRoute: '/map',
        callback: startLocationCallback,
      );
    }

    // Send trip info to the task handler
    if (result is ServiceRequestSuccess) {
      // Small delay to ensure the isolate is ready
      await Future.delayed(const Duration(milliseconds: 500));
      FlutterForegroundTask.sendDataToTask({
        'action': 'start',
        'tripCode': tripCode,
        'userId': userId,
        'parkingMode': parkingMode,
        'isLowBattery': false, // Initial default
      });
      return true;
    }

    return false;
  }

  /// Toggle parking mode on/off.
  static void toggleParkingMode(bool enabled) {
    FlutterForegroundTask.sendDataToTask({
      'action': 'toggleParking',
      'parkingMode': enabled,
    });
  }

  /// Update the battery status in the task handler.
  static void updateBatteryLevel(bool isLow) {
    FlutterForegroundTask.sendDataToTask({
      'action': 'updateBattery',
      'isLowBattery': isLow,
    });
  }

  /// Stop the foreground service and tracking.
  static Future<ServiceRequestResult> stopTracking() async {
    FlutterForegroundTask.sendDataToTask({'action': 'stop'});
    return FlutterForegroundTask.stopService();
  }
}