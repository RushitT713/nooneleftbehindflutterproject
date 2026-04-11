import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

/// Types of shake events detected.
enum ShakeEventType {
  /// Phone was shaken hard multiple times (intentional or panic shake).
  shake,

  /// A violent single impact was detected (potential crash/accident).
  impact,
}

/// Represents a detected shake or impact event.
class ShakeEvent {
  final ShakeEventType type;
  final double magnitude;
  final DateTime timestamp;

  ShakeEvent({
    required this.type,
    required this.magnitude,
    required this.timestamp,
  });
}

/// Shake sensitivity levels the user can choose from.
enum ShakeSensitivity {
  low('Low', 35.0),
  medium('Medium', 25.0),
  high('High', 18.0);

  const ShakeSensitivity(this.label, this.threshold);
  final String label;
  final double threshold;
}

/// Detects shakes and impacts using the device accelerometer.
///
/// Two detection modes:
/// - **Shake**: 3+ spikes above [shakeThreshold] within [kShakeWindow]
/// - **Impact**: A single spike above [kImpactThreshold]
///
/// After triggering, a [kCooldownDuration] prevents repeated alerts.
class ShakeDetectorService {
  // ── Thresholds (m/s²) ──────────────────────
  /// Net acceleration magnitude for a deliberate shake (adjustable).
  double shakeThreshold = 25.0;

  /// Current sensitivity level.
  ShakeSensitivity sensitivity = ShakeSensitivity.medium;

  /// Net acceleration magnitude for a violent impact (crash).
  static const double kImpactThreshold = 45.0;

  /// Number of shake spikes needed within the window.
  static const int kShakeCount = 3;

  /// Time window for counting shake spikes.
  static const Duration kShakeWindow = Duration(seconds: 2);

  /// Cooldown after a detection before another can trigger.
  static const Duration kCooldownDuration = Duration(seconds: 30);

  /// Updates the shake sensitivity at runtime.
  void setSensitivity(ShakeSensitivity level) {
    sensitivity = level;
    shakeThreshold = level.threshold;
  }

  // ── Internal State ─────────────────────────
  StreamSubscription? _accelerometerSubscription;
  final _eventController = StreamController<ShakeEvent>.broadcast();
  final List<DateTime> _recentShakes = [];
  DateTime? _lastTriggerTime;
  bool _isListening = false;

  /// Stream of detected shake/impact events.
  Stream<ShakeEvent> get events => _eventController.stream;

  /// Whether the detector is currently active.
  bool get isListening => _isListening;

  /// Starts listening to the accelerometer.
  void start() {
    if (_isListening) return;
    _isListening = true;

    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen(_onAccelerometerEvent);
  }

  /// Stops listening and cleans up.
  void stop() {
    _isListening = false;
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _recentShakes.clear();
  }

  /// Disposes all resources.
  void dispose() {
    stop();
    _eventController.close();
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    // Calculate net acceleration magnitude (remove gravity ~9.8)
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    final netMagnitude = (magnitude - 9.8).abs();

    // Check cooldown
    if (_lastTriggerTime != null) {
      final elapsed = DateTime.now().difference(_lastTriggerTime!);
      if (elapsed < kCooldownDuration) return;
    }

    // Impact detection — single violent spike
    if (netMagnitude >= kImpactThreshold) {
      _trigger(ShakeEvent(
        type: ShakeEventType.impact,
        magnitude: netMagnitude,
        timestamp: DateTime.now(),
      ));
      return;
    }

    // Shake detection — multiple spikes within time window
    if (netMagnitude >= shakeThreshold) {
      final now = DateTime.now();
      _recentShakes.add(now);

      // Remove old entries outside the window
      _recentShakes.removeWhere(
        (t) => now.difference(t) > kShakeWindow,
      );

      if (_recentShakes.length >= kShakeCount) {
        _trigger(ShakeEvent(
          type: ShakeEventType.shake,
          magnitude: netMagnitude,
          timestamp: now,
        ));
      }
    }
  }

  void _trigger(ShakeEvent event) {
    _lastTriggerTime = DateTime.now();
    _recentShakes.clear();
    _eventController.add(event);
  }
}
