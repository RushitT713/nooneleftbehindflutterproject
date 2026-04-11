import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../constants.dart';
import '../providers/trip_provider.dart';
import '../models/sos_model.dart';
import '../models/trip_model.dart';
import '../services/connectivity_service.dart';
import '../services/location_service.dart';
import '../services/trip_service.dart';
import '../services/shake_detector_service.dart';
import '../services/sos_service.dart';
import '../services/route_service.dart';
import '../utils/navigation_utils.dart';
import '../widgets/bobblehead_marker.dart';
import '../widgets/convoy_panel.dart';
import '../widgets/convoy_drawer.dart';
import '../widgets/trip_summary_dialog.dart';
import 'splash_screen.dart';
import 'sos_screen.dart';
import 'halt_screen.dart';
import 'chat_screen.dart';
import '../utils/page_transitions.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription<DatabaseEvent>? _locationSubscription;
  StreamSubscription<DatabaseEvent>? _memberSubscription;
  StreamSubscription<DatabaseEvent>? _metadataSubscription;
  StreamSubscription<Position>? _directGpsSubscription;
  StreamSubscription<ShakeEvent>? _shakeSubscription;
  StreamSubscription<SosModel?>? _sosSubscription;
  StreamSubscription<bool>? _connectivitySub;
  SosModel? _activeSos;
  bool _isOnline = true;

  final ShakeDetectorService _shakeDetector = ShakeDetectorService();
  bool _isShakeDialogShowing = false;
  bool _isSummaryDialogShowing = false;

  Map<String, Map<String, dynamic>> _convoyLocations = {};
  Map<String, Map<String, dynamic>> _convoyMembers = {};

  final LatLng _defaultCenter = const LatLng(22.3039, 70.8022);
  final MapController _mapController = MapController();
  bool _hasCenteredOnUser = false;

  // ── Destination / Route ─────────────────────────
  TripDestination? _destination;
  List<LatLng> _routePoints = [];
  RouteResult? _routeResult;
  bool _isFetchingRoute = false;

  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityService().isOnline;
    _connectivitySub = ConnectivityService().onConnectivityChanged.listen((isOnline) {
      if (mounted) setState(() => _isOnline = isOnline);
    });
    _initializeTrackingAndListening();
    _startShakeDetector();
  }

  void _startShakeDetector() {
    _shakeDetector.start();
    _shakeSubscription = _shakeDetector.events.listen(_onShakeDetected);
  }

  void _onShakeDetected(ShakeEvent event) {
    if (_isShakeDialogShowing) return;
    _isShakeDialogShowing = true;
    _showShakeCountdownDialog(event);
  }

  void _showShakeCountdownDialog(ShakeEvent event) {
    final provider = context.read<TripProvider>();
    final tripCode = provider.tripCode;
    if (tripCode == null) {
      _isShakeDialogShowing = false;
      return;
    }

    final isImpact = event.type == ShakeEventType.impact;
    final title = isImpact ? '💥 Impact Detected!' : '📳 Shake Detected!';
    final subtitle = isImpact
        ? 'A violent impact was detected.\nSOS will be sent automatically.'
        : 'Repeated shaking detected.\nSOS will be sent automatically.';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _ShakeCountdownDialog(
        title: title,
        subtitle: subtitle,
        onCancel: () {
          Navigator.pop(dialogCtx);
          _isShakeDialogShowing = false;
        },
        onAutoSend: () async {
          Navigator.pop(dialogCtx);
          _isShakeDialogShowing = false;

          // Auto-trigger SOS with 'accident' reason
          final userId = provider.userId ?? '';
          final nickname = provider.nickname ?? 'Unknown';
          double lat = 0.0;
          double lng = 0.0;
          try {
            final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
            lat = pos.latitude;
            lng = pos.longitude;
          } catch (_) {}

          final sosService = SosService();
          await sosService.triggerSos(
            tripCode: tripCode,
            userId: userId,
            userName: nickname,
            reason: SosReason.accident,
            note: isImpact ? 'Auto-detected: Possible impact/crash' : 'Auto-detected: Device shake',
            lat: lat,
            lng: lng,
          );

          if (mounted) {
            Navigator.of(context).push(
              SlideUpRoute(
                page: SosScreen(
                  tripCode: tripCode,
                  autoReason: SosReason.accident,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _initializeTrackingAndListening() {
    final provider = context.read<TripProvider>();
    final tripCode = provider.tripCode;
    final userId = provider.userId ?? FirebaseAuth.instance.currentUser?.uid;

    if (tripCode != null && userId != null) {
      // 1. Start foreground service (background pipeline)
      LocationService.startTracking(
        tripCode: tripCode,
        userId: userId,
        parkingMode: provider.isParkingMode,
      );

      // 2. Direct GPS: fetch position NOW and center map + push to Firebase
      _startDirectGps(tripCode, userId);

      // 3. Listen for convoy data from Firebase
      _listenToConvoy(tripCode);
    }
  }

  /// Directly fetch GPS and stream updates — doesn't depend on foreground service.
  void _startDirectGps(String tripCode, String userId) async {
    // Immediate position fetch
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _handleGpsFix(position, tripCode, userId);
    } catch (e) {
      // GPS not available yet, stream will catch it
    }

    // Continuous stream as direct fallback
    _directGpsSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      _handleGpsFix(position, tripCode, userId);
    });
  }

  void _handleGpsFix(Position position, String tripCode, String userId) {
    final lat = position.latitude;
    final lng = position.longitude;
    final speedKmH = position.speed * 3.6;

    // Center map on first GPS fix
    if (!_hasCenteredOnUser) {
      _hasCenteredOnUser = true;
      _mapController.move(LatLng(lat, lng), 15.0);
    }

    // Push to Firebase so the marker appears on all devices
    final ref = FirebaseDatabase.instance
        .ref(liveLocationPath(tripCode, userId));
    ref.set({
      'lat': lat,
      'lng': lng,
      'speed': double.parse(speedKmH.toStringAsFixed(1)),
      'heading': double.parse(position.heading.toStringAsFixed(1)),
      'accuracy': double.parse(position.accuracy.toStringAsFixed(1)),
      'ts': ServerValue.timestamp,
    });
  }

  void _listenToConvoy(String tripCode) {
    DatabaseReference locationsRef =
        FirebaseDatabase.instance.ref(liveLocationsPath(tripCode));
    _locationSubscription = locationsRef.onValue.listen((event) {
      final val = event.snapshot.value;
      if (val is Map<dynamic, dynamic>) {
        setState(() {
          final newLocs = <String, Map<String, dynamic>>{};
          val.forEach((key, value) {
            if (value is Map) {
              newLocs[key.toString()] = Map<String, dynamic>.from(value);
            }
          });
          _convoyLocations = newLocs;
        });
      }
    });

    DatabaseReference membersRef =
        FirebaseDatabase.instance.ref(membersPath(tripCode));
    _memberSubscription = membersRef.onValue.listen((event) {
      final val = event.snapshot.value;
      if (val is Map<dynamic, dynamic>) {
        setState(() {
          final newMem = <String, Map<String, dynamic>>{};
          val.forEach((key, value) {
            if (value is Map) {
              newMem[key.toString()] = Map<String, dynamic>.from(value);
            }
          });
          _convoyMembers = newMem;
        });
      }
    });

    _sosSubscription = SosService().listenToActiveSos(tripCode).listen((sos) {
      if (mounted) {
        setState(() => _activeSos = sos);
      }
    });

    // Listen to trip metadata for destination changes and trip end
    final metadataRef =
        FirebaseDatabase.instance.ref(metadataPath(tripCode));
    _metadataSubscription = metadataRef.onValue.listen((event) {
      final val = event.snapshot.value;
      if (val is Map<dynamic, dynamic>) {
        final statusStr = val['status']?.toString();
        if (statusStr == TripStatus.ended.name && mounted && !_isSummaryDialogShowing) {
           _isSummaryDialogShowing = true;
           showDialog(
             context: context,
             barrierDismissible: false,
             builder: (ctx) => TripSummaryDialog(
               meta: val,
               memberCount: _convoyMembers.length,
             ),
           );
           return;
        }

        final destData = val['destination'];
        TripDestination? newDest;
        if (destData is Map<dynamic, dynamic>) {
          newDest = TripDestination.fromMap(destData);
        }

        if (mounted) {
          final oldDest = _destination;
          setState(() => _destination = newDest);

          // Re-fetch route if destination changed
          if (newDest != null &&
              (oldDest == null ||
                  oldDest.lat != newDest.lat ||
                  oldDest.lng != newDest.lng)) {
            _fetchRouteToDestination(newDest);
          } else if (newDest == null) {
            setState(() {
              _routePoints = [];
              _routeResult = null;
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _memberSubscription?.cancel();
    _metadataSubscription?.cancel();
    _directGpsSubscription?.cancel();
    _shakeSubscription?.cancel();
    _sosSubscription?.cancel();
    _connectivitySub?.cancel();
    _shakeDetector.dispose();
    super.dispose();
  }

  // ── Math Helpers ────────────────────────────────────
  double _toRadians(double degree) => degree * math.pi / 180.0;

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  // ── Map Controls ────────────────────────────────────
  void _centerOnMe() {
    final myUserId =
        context.read<TripProvider>().userId ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';
    final myLoc = _convoyLocations[myUserId];
    if (myLoc != null) {
      _mapController.move(
        LatLng(myLoc['lat'].toDouble(), myLoc['lng'].toDouble()),
        _mapController.camera.zoom,
      );
    }
  }

  void _centerOnConvoy() {
    if (_convoyLocations.isEmpty) return;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final loc in _convoyLocations.values) {
      final lat = loc['lat'].toDouble();
      final lng = loc['lng'].toDouble();
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat, minLng),
          LatLng(maxLat, maxLng),
        ),
        padding: const EdgeInsets.all(80),
      ),
    );
  }

  /// Center the map on a specific member's location.
  void _locateMember(String uid) {
    final locData = _convoyLocations[uid];
    if (locData != null) {
      final lat = locData['lat']?.toDouble();
      final lng = locData['lng']?.toDouble();
      if (lat != null && lng != null) {
        _mapController.move(LatLng(lat, lng), 17.0);
      }
    }
  }

  // ── Destination Methods ─────────────────────────────

  /// Handle long-press on the map to set destination (Host only).
  void _onMapLongPress(TapPosition tapPosition, LatLng point) {
    final provider = context.read<TripProvider>();
    if (!provider.isHost) return;

    _showDestinationConfirmDialog(point.latitude, point.longitude);
  }

  /// Shows a dialog to confirm and name a long-pressed destination.
  void _showDestinationConfirmDialog(double lat, double lng) async {
    final provider = context.read<TripProvider>();
    final tripCode = provider.tripCode;
    if (tripCode == null) return;

    // Try to reverse-geocode the location name
    String placeName = 'Destination';
    final name = await RouteService.reverseGeocode(lat, lng);
    if (name != null && name.isNotEmpty) {
      // Take only the first few parts for a readable name
      final parts = name.split(',');
      placeName = parts.take(3).join(',').trim();
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBackground,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.flag_rounded, color: kPrimary),
            SizedBox(width: 8),
            Text('Set Destination',
                style: TextStyle(
                    fontFamily: 'Thicccboi', fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(placeName, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
              style: const TextStyle(
                  color: kTextTertiary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Set Destination'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await TripService().setDestination(
        tripCode: tripCode,
        name: placeName,
        lat: lat,
        lng: lng,
      );
    }
  }

  /// Show search dialog for the host to find and set a destination.
  void _showSearchDestinationDialog() {
    final provider = context.read<TripProvider>();
    final tripCode = provider.tripCode;
    if (tripCode == null) return;

    showDialog(
      context: context,
      builder: (ctx) => _DestinationSearchDialog(
        onPlaceSelected: (name, lat, lng) async {
          Navigator.pop(ctx);
          await TripService().setDestination(
            tripCode: tripCode,
            name: name,
            lat: lat,
            lng: lng,
          );
        },
      ),
    );
  }

  /// Clear the destination.
  void _clearDestination(String? tripCode) async {
    if (tripCode == null) return;
    await TripService().clearDestination(tripCode);
  }

  /// Fetch real road route from OSRM.
  void _fetchRouteToDestination(TripDestination dest) async {
    if (_isFetchingRoute) return;
    _isFetchingRoute = true;

    // Get my current location
    final provider = context.read<TripProvider>();
    final myUid = provider.userId ?? FirebaseAuth.instance.currentUser?.uid;
    final myLoc = myUid != null ? _convoyLocations[myUid] : null;

    double originLat, originLng;
    if (myLoc != null) {
      originLat = myLoc['lat'].toDouble();
      originLng = myLoc['lng'].toDouble();
    } else {
      // Fallback: use last known position
      try {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          originLat = pos.latitude;
          originLng = pos.longitude;
        } else {
          _isFetchingRoute = false;
          return;
        }
      } catch (_) {
        _isFetchingRoute = false;
        return;
      }
    }

    final result = await RouteService.getRoute(
      originLat: originLat,
      originLng: originLng,
      destLat: dest.lat,
      destLng: dest.lng,
    );

    _isFetchingRoute = false;
    if (mounted && result != null) {
      setState(() {
        _routePoints = result.points;
        _routeResult = result;
      });
    }
  }

  // ── Build Markers ─────────────────────────────────
  List<Marker> _buildMarkers(String myUserId) {
    List<Marker> markers = [];

    Map<String, dynamic>? myLocData = _convoyLocations[myUserId];
    double? myLat = myLocData?['lat']?.toDouble();
    double? myLng = myLocData?['lng']?.toDouble();

    _convoyMembers.forEach((uid, memberData) {
      bool isMe = uid == myUserId;

      Map<String, dynamic>? locData = _convoyLocations[uid];
      double lat = locData?['lat']?.toDouble() ?? _defaultCenter.latitude;
      double lng = locData?['lng']?.toDouble() ?? _defaultCenter.longitude;
      double heading = (locData?['heading'] ?? 0.0).toDouble();
      double headingRadians = _toRadians(heading);

      String distanceText = '';
      String? compass;

      if (!isMe && myLat != null && myLng != null && locData != null) {
        double dist = _calculateDistance(myLat, myLng, lat, lng);
        distanceText = '${dist.toStringAsFixed(1)} km';
        compass = compassDirection(myLat, myLng, lat, lng);
      } else if (!isMe && locData == null) {
        distanceText = 'No GPS';
      }

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 140,
          height: 160,
          child: BobbleheadMarker(
            nickname: memberData['nickname'] ?? 'Unknown',
            photoUrl: (memberData['photoUrl'] ?? '').toString(),
            vehicleType: (memberData['vehicleType'] ?? 'Car').toString(),
            headingRadians: headingRadians,
            isMe: isMe,
            distanceText: distanceText,
            compassDirection: compass,
          ),
        ),
      );
    });

    return markers;
  }

  // ── Leave / Disband Dialog ────────────────────────
  final TripService _tripService = TripService();

  void _showLeaveDialog(BuildContext context) {
    final provider = context.read<TripProvider>();
    final isHost = provider.isHost;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kSurfaceBorder, width: 1),
        ),
        title: Text(
          isHost ? 'End Trip?' : 'Leave Convoy?',
          style: const TextStyle(
              color: kTextPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isHost
              ? 'This will end the trip for all members and save the trip history.'
              : 'You will leave the convoy. You can rejoin with the trip code as long as the trip is active.',
          style: const TextStyle(color: kTextSecondary),
        ),
        actions: isHost
            ? [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel',
                      style: TextStyle(color: kTextTertiary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _tripService.endTrip(
                      tripCode: provider.tripCode!,
                    );
                    // The _metadataSubscription will detect the 'ended' status 
                    // and show the TripSummaryDialog automatically.
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: kAlertRed),
                  child: const Text('End Trip',
                      style: TextStyle(color: Colors.white)),
                ),
              ]
            : [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel',
                      style: TextStyle(color: kTextTertiary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _tripService.leaveTrip(
                      tripCode: provider.tripCode!,
                      userUid: provider.userId!,
                    );
                    await LocationService.stopTracking();
                    await provider.clearTrip();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        FadeSlideRoute(
                            page: const SplashScreen()),
                        (route) => false,
                      );
                    }
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: kAlertRed),
                  child: const Text('Leave',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
      ),
    );
  }

  // ── Map Type ────────────────────────────────────────
  // Enum for map tile sources
  static const _tileUrls = {
    'Default': 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
    'Satellite': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'Terrain': 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
  };

  String _mapType = 'Satellite'; // default

  void _showMapTypePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Map Type',
                style: TextStyle(
                  fontFamily: 'Thicccboi',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: ['Default', 'Satellite', 'Terrain'].map((type) {
                  final isSelected = _mapType == type;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _mapType = type);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? kPrimaryLight : kSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? kPrimary : kSurfaceBorder,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              type == 'Default'
                                  ? Icons.map_outlined
                                  : type == 'Satellite'
                                      ? Icons.satellite_alt
                                      : Icons.terrain,
                              color: isSelected ? kPrimary : kTextSecondary,
                              size: 24,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              type,
                              style: TextStyle(
                                fontFamily: 'Thicccboi',
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 13,
                                color: isSelected ? kPrimary : kTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final tripCode = provider.tripCode;
    final myUserId = provider.userId ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';

    // Determine tile URL and subdomains based on selected map type
    final tileUrl = _tileUrls[_mapType]!;
    final subdomains = _mapType == 'Satellite' ? <String>[] : const ['a', 'b', 'c', 'd'];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kBackground,
      drawer: ConvoyDrawer(
        myUserId: myUserId,
        nickname: provider.nickname,
        vehicleType: provider.vehicleType,
        photoUrl: provider.photoUrl,
        tripCode: tripCode,
        isHost: provider.isHost,
        isParkingMode: provider.isParkingMode,
        members: _convoyMembers,
        locations: _convoyLocations,
        shakeDetector: _shakeDetector,
        onParkingToggle: () => provider.toggleParkingMode(),
        onLocateMember: _locateMember,
        destination: _destination,
        onSetDestination: _showSearchDestinationDialog,
        onClearDestination: () => _clearDestination(tripCode),
        onKickMember: (uid) {
          if (tripCode != null) {
            TripService().kickMember(tripCode: tripCode, targetUid: uid);
          }
        },
        onTransferHost: (uid) {
          if (tripCode != null) {
            TripService().transferHost(tripCode: tripCode, currentHostUid: myUserId, newHostUid: uid);
          }
        },
      ),
      body: Stack(
        children: [
          // 1. THE MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 15.0,
              onLongPress: _onMapLongPress,
            ),
            children: [
              // --- Dark Mode Color Filter for Night Driving ---
              ColorFiltered(
                colorFilter: Theme.of(context).brightness == Brightness.dark
                    ? const ColorFilter.matrix(<double>[
                        -0.2126, -0.7152, -0.0722, 0, 255,
                        -0.2126, -0.7152, -0.0722, 0, 255,
                        -0.2126, -0.7152, -0.0722, 0, 255,
                         0,       0,       0,      1,   0,
                      ])
                    : const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.multiply,
                      ),
                child: TileLayer(
                  urlTemplate: tileUrl,
                  subdomains: subdomains,
                  userAgentPackageName: 'com.example.no_one_left_behind',
                ),
              ),
              MarkerLayer(
                markers: [
                  ..._buildMarkers(myUserId),
                  if (_destination != null)
                    Marker(
                      point: LatLng(_destination!.lat, _destination!.lng),
                      width: 50,
                      height: 60,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: kAlertRed,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '📍',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const Icon(Icons.place,
                              color: kAlertRed, size: 30),
                        ],
                      ),
                    ),
                ],
              ),
              // Route polyline
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: kPrimary,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
            ],
          ),

          // 2. TOP BAR — Menu + Convoy Title + Leave
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isOnline)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: kAlertRed.withValues(alpha: 0.95),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'RECONNECTING...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: kBackground.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: kSurfaceBorder, width: 1),
                ),
                child: Row(
                  children: [
                    // Menu / hamburger button
                    Container(
                      decoration: BoxDecoration(
                        color: kSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: kSurfaceBorder, width: 1),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.menu, color: kTextPrimary, size: 20),
                        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                        constraints: const BoxConstraints.tightFor(
                            width: 40, height: 40),
                        padding: EdgeInsets.zero,
                      ),
                    ),

                    // Center: Convoy title
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Convoy',
                            style: TextStyle(
                              color: kTextPrimary,
                              fontFamily: 'Thicccboi',
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: kOnlineGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'ACTIVE SESSION',
                                style: TextStyle(
                                  color: kOnlineGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Leave button
                    GestureDetector(
                      onTap: () => _showLeaveDialog(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: kAlertRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: kAlertRed.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'Leave',
                          style: TextStyle(
                            color: kAlertRed,
                            fontFamily: 'Thicccboi',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
              ],
            ),
          ),

          // 3. LEFT SIDE — SOS + Halt quick-action buttons
          Positioned(
            left: 16,
            top: MediaQuery.of(context).padding.top + 84,
            child: Column(
              children: [
                // SOS / Fire button
                _MapControlButton(
                  icon: Icons.local_fire_department,
                  color: kAlertRed,
                  bgColor: kBackground,
                  borderColor: kAlertRed.withValues(alpha: 0.3),
                  onPressed: () {
                    final code = provider.tripCode;
                    if (code == null) return;
                    Navigator.of(context).push(
                      SlideUpRoute(
                        page: SosScreen(tripCode: code),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                // Halt / hand-stop button
                _MapControlButton(
                  icon: Icons.back_hand,
                  color: kHaltAmber,
                  bgColor: kBackground,
                  borderColor: kHaltAmber.withValues(alpha: 0.3),
                  onPressed: () {
                    final code = provider.tripCode;
                    if (code == null) return;
                    Navigator.of(context).push(
                      SlideUpRoute(
                        page: HaltScreen(tripCode: code),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                // Chat / Broadcast Message button
                _MapControlButton(
                  icon: Icons.chat_bubble_outline,
                  color: kPrimary,
                  bgColor: kBackground,
                  borderColor: kPrimary.withValues(alpha: 0.3),
                  onPressed: () {
                    final code = provider.tripCode;
                    if (code == null) return;
                    Navigator.of(context).push(
                      SlideUpRoute(
                        page: ChatScreen(tripCode: code),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // 4. RIGHT SIDE — Map type + zoom + locate controls
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 84,
            child: Column(
              children: [
                // Map type selector
                _MapControlButton(
                  icon: Icons.layers_outlined,
                  color: kTextPrimary,
                  bgColor: kBackground,
                  borderColor: kSurfaceBorder,
                  onPressed: _showMapTypePicker,
                ),
                const SizedBox(height: 8),
                // Zoom In
                _MapControlButton(
                  icon: Icons.add,
                  color: kTextPrimary,
                  bgColor: kBackground,
                  borderColor: kSurfaceBorder,
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Zoom Out
                _MapControlButton(
                  icon: Icons.remove,
                  color: kTextPrimary,
                  bgColor: kBackground,
                  borderColor: kSurfaceBorder,
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                ),
                const SizedBox(height: 14),
                // Center on Convoy
                _MapControlButton(
                  icon: Icons.group,
                  color: kPrimary,
                  bgColor: kBackground,
                  borderColor: kPrimary.withValues(alpha: 0.3),
                  onPressed: _centerOnConvoy,
                ),
                const SizedBox(height: 8),
                // Center on Me
                _MapControlButton(
                  icon: Icons.my_location,
                  color: kAccentBlue,
                  bgColor: kBackground,
                  borderColor: kAccentBlue.withValues(alpha: 0.3),
                  onPressed: _centerOnMe,
                ),
              ],
            ),
          ),

          // 5. DESTINATION INFO BAR (Floating)
          if (_destination != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 130, // Above the ConvoyPanel
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: kBackground.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kPrimary.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kPrimaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.near_me_rounded, color: kPrimary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _destination!.name,
                            style: const TextStyle(
                              color: kTextPrimary,
                              fontFamily: 'Thicccboi',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_isFetchingRoute)
                            const Text(
                              'Calculating route...',
                              style: TextStyle(color: kTextTertiary, fontSize: 12),
                            )
                          else if (_routeResult != null)
                            Text(
                              '${_routeResult!.distanceText} • ${_routeResult!.durationText}',
                              style: const TextStyle(
                                  color: kPrimaryDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        final myLoc = _convoyLocations[myUserId];
                        if (myLoc != null) {
                          NavigationUtils.openRouteInGoogleMaps(
                            originLat: myLoc['lat'].toDouble(),
                            originLng: myLoc['lng'].toDouble(),
                            destLat: _destination!.lat,
                            destLng: _destination!.lng,
                          );
                        } else {
                          NavigationUtils.navigateToMember(
                            lat: _destination!.lat,
                            lng: _destination!.lng,
                          );
                        }
                      },
                      child: const Text(
                        'GO',
                        style: TextStyle(
                            fontFamily: 'Thicccboi',
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 6. CONVOY BOTTOM PANEL
          Align(
            alignment: Alignment.bottomCenter,
            child: ConvoyPanel(
              members: _convoyMembers,
              locations: _convoyLocations,
              myUserId: myUserId,
              tripCode: tripCode,
              isHost: provider.isHost,
              distanceCalculator: _calculateDistance,
              compassCalculator: compassDirection,
              onLocateMember: (uid) {
                final loc = _convoyLocations[uid];
                if (loc != null) {
                  _mapController.move(
                      LatLng(loc['lat'].toDouble(), loc['lng'].toDouble()), 16.0);
                }
              },
              onKickMember: provider.isHost ? (uid) {
                if (tripCode != null) {
                  TripService().kickMember(tripCode: tripCode, targetUid: uid);
                }
              } : null,
              onTransferHost: provider.isHost ? (uid) {
                if (tripCode != null) {
                  TripService().transferHost(tripCode: tripCode, currentHostUid: myUserId, newHostUid: uid);
                }
              } : null,
            ),
          ),

          // 6. GLOBAL SOS ALERT BAR (Floating)
          if (_activeSos != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 140, // Above the bottom panel
              child: GestureDetector(
                onTap: () {
                  final code = provider.tripCode;
                  if (code == null) return;
                  Navigator.of(context).push(
                    SlideUpRoute(
                      page: SosScreen(tripCode: code),
                    ),
                  );
                },
                child: Hero(
                  tag: 'sos_alert_bar',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: kAlertRed,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: kAlertRed.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'SOS: ${_activeSos!.triggerName.toUpperCase()}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Thicccboi',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _activeSos!.reason.name.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'VIEW',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Map Control Button Widget ──────────────────────
class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final Color? bgColor;
  final Color? borderColor;

  const _MapControlButton({
    required this.icon,
    required this.onPressed,
    this.color = kTextPrimary,
    this.bgColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor ?? kBackground,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? kSurfaceBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

// ─── Shake/Impact Countdown Dialog ──────────────

class _ShakeCountdownDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final VoidCallback onCancel;
  final VoidCallback onAutoSend;

  const _ShakeCountdownDialog({
    required this.title,
    required this.subtitle,
    required this.onCancel,
    required this.onAutoSend,
  });

  @override
  State<_ShakeCountdownDialog> createState() => _ShakeCountdownDialogState();
}

class _ShakeCountdownDialogState extends State<_ShakeCountdownDialog>
    with SingleTickerProviderStateMixin {
  int _secondsLeft = 5;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        widget.onAutoSend();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),

          // Pulsing SOS icon
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + _pulseController.value * 0.15,
                child: child,
              );
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: kAlertRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sos, size: 40, color: kAlertRed),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Thicccboi',
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: kTextSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Countdown
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: kAlertRed.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: kAlertRed, width: 3),
            ),
            child: Center(
              child: Text(
                '$_secondsLeft',
                style: const TextStyle(
                  fontFamily: 'Thicccboi',
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  color: kAlertRed,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'seconds until SOS is sent',
            style: TextStyle(
              color: kTextTertiary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),

          // Cancel button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: widget.onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: kTextPrimary,
                side: const BorderSide(color: kSurfaceBorder, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "I'm OK — Cancel",
                style: TextStyle(
                  fontFamily: 'Thicccboi',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Destination Search Dialog ─────────────────────────
class _DestinationSearchDialog extends StatefulWidget {
  final void Function(String name, double lat, double lng) onPlaceSelected;

  const _DestinationSearchDialog({required this.onPlaceSelected});

  @override
  State<_DestinationSearchDialog> createState() =>
      _DestinationSearchDialogState();
}

class _DestinationSearchDialogState extends State<_DestinationSearchDialog> {
  final _controller = TextEditingController();
  List<PlaceResult> _results = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _search(query);
    });
  }

  void _search(String query) async {
    if (query.trim().length < 3) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isSearching = true);

    final results = await RouteService.searchPlaces(query);

    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.search_rounded, color: kPrimary),
                SizedBox(width: 8),
                Text(
                  'Search Destination',
                  style: TextStyle(
                    fontFamily: 'Thicccboi',
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: kTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              onChanged: _onSearchChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search for a place...',
                hintStyle: const TextStyle(color: kTextTertiary),
                prefixIcon:
                    const Icon(Icons.place_outlined, color: kTextTertiary),
                filled: true,
                fillColor: kSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kSurfaceBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kSurfaceBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kPrimary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 10),

            if (_isSearching)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: kPrimary),
                ),
              ),

            if (!_isSearching && _results.isNotEmpty)
              ConstrainedBox(
                constraints:
                    const BoxConstraints(maxHeight: 300),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: kSurfaceBorder, height: 1),
                  itemBuilder: (context, index) {
                    final place = _results[index];
                    // Short display name
                    final parts = place.name.split(',');
                    final shortName =
                        parts.take(3).join(',').trim();

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kPrimaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.place,
                            color: kPrimary, size: 20),
                      ),
                      title: Text(
                        shortName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => widget.onPlaceSelected(
                          shortName, place.lat, place.lng),
                    );
                  },
                ),
              ),

            if (!_isSearching &&
                _results.isEmpty &&
                _controller.text.length >= 3)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No places found.',
                    style: TextStyle(color: kTextTertiary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}