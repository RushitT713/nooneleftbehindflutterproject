import 'dart:async';
import 'package:battery_plus/battery_plus.dart';

class BatteryService {
  static final BatteryService _instance = BatteryService._internal();
  factory BatteryService() => _instance;
  BatteryService._internal();

  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _subscription;
  
  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.full;

  int get batteryLevel => _batteryLevel;
  BatteryState get batteryState => _batteryState;
  bool get isLowBattery => _batteryLevel <= 20 && _batteryState != BatteryState.charging;

  final StreamController<int> _levelController = StreamController<int>.broadcast();
  Stream<int> get onBatteryLevelChanged => _levelController.stream;

  Future<void> init() async {
    _batteryLevel = await _battery.batteryLevel;
    _subscription = _battery.onBatteryStateChanged.listen((state) async {
      _batteryState = state;
      _batteryLevel = await _battery.batteryLevel;
      _levelController.add(_batteryLevel);
    });

    // Initial check
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      _batteryLevel = await _battery.batteryLevel;
      _levelController.add(_batteryLevel);
    });
  }

  void dispose() {
    _subscription?.cancel();
    _levelController.close();
  }
}
