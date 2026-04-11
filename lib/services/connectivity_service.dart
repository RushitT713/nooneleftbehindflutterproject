import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal() {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  final _connectionStatusController = StreamController<bool>.broadcast();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Stream<bool> get onConnectivityChanged => _connectionStatusController.stream;

  void _init() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateStatus(results);
    });
    checkConnectivity();
  }

  Future<void> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    bool online = !results.contains(ConnectivityResult.none);
    
    // In some cases results might be empty or behave differently, so fallback check:
    if (results.isEmpty) {
      online = false;
    }

    if (_isOnline != online) {
      _isOnline = online;
      _connectionStatusController.add(_isOnline);
    }
  }

  void dispose() {
    _connectionStatusController.close();
  }
}
