import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../utils/navigation_utils.dart';
import '../widgets/member_detail_sheet.dart';

/// Bottom convoy panel — light theme, minimalist design.
/// Shows current speed + trip code info bar, nearby convoy member cards,
/// and a Broadcast Message CTA button.
class ConvoyPanel extends StatelessWidget {
  final Map<String, Map<String, dynamic>> members;
  final Map<String, Map<String, dynamic>> locations;
  final String myUserId;
  final String? tripCode;
  final bool isHost;
  final double Function(double, double, double, double) distanceCalculator;
  final String Function(double, double, double, double) compassCalculator;
  final void Function(String uid) onLocateMember;
  final void Function(String)? onKickMember;
  final void Function(String)? onTransferHost;

  const ConvoyPanel({
    super.key,
    required this.members,
    required this.locations,
    required this.myUserId,
    this.tripCode,
    this.isHost = false,
    required this.distanceCalculator,
    required this.compassCalculator,
    required this.onLocateMember,
    this.onKickMember,
    this.onTransferHost,
  });

  @override
  Widget build(BuildContext context) {
    // Get my speed
    final myLoc = locations[myUserId];
    final mySpeed = (myLoc?['speed'] ?? 0.0).toDouble();

    // Build nearby members list (exclude self)
    final nearby = members.entries.where((e) => e.key != myUserId).toList();
    nearby.sort((a, b) {
      final nameA = (a.value['nickname'] ?? '').toString();
      final nameB = (b.value['nickname'] ?? '').toString();
      return nameA.compareTo(nameB);
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.30,
      minChildSize: 0.12,
      maxChildSize: 0.55,
      snap: true,
      snapSizes: const [0.12, 0.30, 0.55],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: kBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: const Border(
              top: BorderSide(color: kSurfaceBorder, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              // ── Drag Handle ────────────────────────────
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kSurfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Speed + Trip Code Info Bar ─────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kSurfaceBorder, width: 1),
                  ),
                  child: Row(
                    children: [
                      // Speedometer icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kPrimaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.speed, color: kPrimary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      // Speed info
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CURRENT SPEED',
                            style: TextStyle(
                              color: kTextTertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${mySpeed.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: kTextPrimary,
                                  fontSize: 24,
                                  fontFamily: 'Thicccboi',
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Text(
                                'km/h',
                                style: TextStyle(
                                  color: kTextSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Divider
                      Container(
                        height: 40,
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: kSurfaceBorder,
                      ),

                      // Trip Code
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TRIP CODE',
                              style: TextStyle(
                                color: kTextTertiary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tripCode ?? '------',
                              style: const TextStyle(
                                color: kTextPrimary,
                                fontSize: 20,
                                fontFamily: 'Thicccboi',
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Copy / QR button
                      GestureDetector(
                        onTap: () {
                          if (tripCode != null) {
                            Clipboard.setData(ClipboardData(text: tripCode!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Trip code copied!'),
                                backgroundColor: kPrimary,
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kPrimaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.qr_code_2, color: kPrimary, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── NEARBY CONVOY Header ───────────────────
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'NEARBY CONVOY',
                  style: TextStyle(
                    color: kTextTertiary,
                    fontSize: 11,
                    fontFamily: 'Thicccboi',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              // ── Member Cards ───────────────────────────
              if (nearby.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Text(
                    'No other convoy members yet.',
                    style: TextStyle(color: kTextTertiary, fontSize: 13),
                  ),
                )
              else
                ...nearby.map((entry) {
                  final uid = entry.key;
                  final data = entry.value;
                  final nickname = (data['nickname'] ?? 'Unknown').toString();
                  final vehicleType = (data['vehicleType'] ?? 'Car').toString();
                  final photoUrl = (data['photoUrl'] ?? '').toString();
                  final isOnline = data['isOnline'] == true;

                  // Location + distance
                  final locData = locations[uid];
                  final speed = (locData?['speed'] ?? 0.0).toDouble();

                  String distText = '';
                  String compass = '';
                  double? bearing;
                  if (locData != null && myLoc != null) {
                    final dist = distanceCalculator(
                      myLoc['lat'].toDouble(),
                      myLoc['lng'].toDouble(),
                      locData['lat'].toDouble(),
                      locData['lng'].toDouble(),
                    );
                    distText = '${dist.toStringAsFixed(1)} km';
                    compass = compassCalculator(
                      myLoc['lat'].toDouble(),
                      myLoc['lng'].toDouble(),
                      locData['lat'].toDouble(),
                      locData['lng'].toDouble(),
                    );
                    // Calculate bearing angle for arrow
                    bearing = _bearingAngle(
                      myLoc['lat'].toDouble(),
                      myLoc['lng'].toDouble(),
                      locData['lat'].toDouble(),
                      locData['lng'].toDouble(),
                    );
                  } else if (locData == null) {
                    distText = 'No GPS';
                  }

                  // Status line
                  String statusLine;
                  if (speed > 1) {
                    statusLine = '${speed.toStringAsFixed(0)} km/h';
                  } else if (isOnline) {
                    statusLine = 'Stationary';
                  } else {
                    statusLine = 'Offline';
                  }

                  return GestureDetector(
                    onTap: () {
                      double? dist;
                      if (locData != null && myLoc != null) {
                        dist = distanceCalculator(
                          myLoc['lat'].toDouble(),
                          myLoc['lng'].toDouble(),
                          locData['lat'].toDouble(),
                          locData['lng'].toDouble(),
                        ) * 1000; // convert km to meters for the sheet
                      }
                      
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => MemberDetailSheet(
                          memberData: data,
                          uid: uid,
                          isMe: false, // Panels only show OTHER members
                          amIHost: isHost,
                          distanceInMeters: dist,
                          onKick: onKickMember,
                          onTransferHost: onTransferHost,
                          onLocate: locData != null ? onLocateMember : null,
                        ),
                      );
                    },
                    child: _NearbyMemberCard(
                      nickname: nickname,
                      vehicleType: vehicleType,
                      photoUrl: photoUrl,
                      isOnline: isOnline,
                      statusLine: statusLine,
                      distText: distText,
                      compass: compass,
                      bearingAngle: bearing,
                      memberLat: locData?['lat']?.toDouble(),
                      memberLng: locData?['lng']?.toDouble(),
                    ),
                  );
                }),

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  /// Calculate bearing angle in radians (for directional arrow icon)
  double _bearingAngle(double lat1, double lng1, double lat2, double lng2) {
    final dLng = _toRadians(lng2 - lng1);
    final lat1R = _toRadians(lat1);
    final lat2R = _toRadians(lat2);

    final y = math.sin(dLng) * math.cos(lat2R);
    final x = math.cos(lat1R) * math.sin(lat2R) -
        math.sin(lat1R) * math.cos(lat2R) * math.cos(dLng);

    return math.atan2(y, x);
  }

  double _toRadians(double deg) => deg * math.pi / 180.0;
}

// ── Nearby Member Card (light theme) ──────────────────
class _NearbyMemberCard extends StatelessWidget {
  final String nickname;
  final String vehicleType;
  final String photoUrl;
  final bool isOnline;
  final String statusLine;
  final String distText;
  final String compass;
  final double? bearingAngle;
  final double? memberLat;
  final double? memberLng;

  const _NearbyMemberCard({
    required this.nickname,
    required this.vehicleType,
    required this.photoUrl,
    required this.isOnline,
    required this.statusLine,
    required this.distText,
    required this.compass,
    this.bearingAngle,
    this.memberLat,
    this.memberLng,
  });

  String get _initials {
    final parts = nickname.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return nickname.isNotEmpty ? nickname[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final vehicleInfo = kVehicles.firstWhere(
      (v) => v.name.toLowerCase() == vehicleType.toLowerCase(),
      orElse: () => kVehicles.first,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kSurfaceBorder, width: 1),
      ),
      child: Row(
        children: [
          // Avatar with online dot
          Stack(
            children: [
              photoUrl.isNotEmpty
                  ? CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(photoUrl),
                      onBackgroundImageError: (e, _) {},
                      backgroundColor: kSurface,
                    )
                  : CircleAvatar(
                      radius: 20,
                      backgroundColor: kPrimaryLight,
                      child: Text(
                        _initials,
                        style: const TextStyle(
                          color: kPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isOnline ? kOnlineGreen : kOfflineGrey,
                    shape: BoxShape.circle,
                    border: Border.all(color: kBackground, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        "$nickname's ${vehicleInfo.name}",
                        style: const TextStyle(
                          color: kTextPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  statusLine,
                  style: TextStyle(
                    color: isOnline ? kTextTertiary : kOfflineGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Distance + directional arrow
          if (distText.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      distText,
                      style: const TextStyle(
                        color: kPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (bearingAngle != null)
                      Transform.rotate(
                        angle: bearingAngle! - (math.pi / 2),
                        child: const Icon(
                          Icons.arrow_forward,
                          color: kPrimary,
                          size: 14,
                        ),
                      ),
                  ],
                ),
                if (compass.isNotEmpty)
                  Text(
                    compass,
                    style: const TextStyle(color: kTextTertiary, fontSize: 11),
                  ),
              ],
            ),

          // Navigate button
          if (memberLat != null && memberLng != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () => NavigationUtils.navigateToMember(
                  lat: memberLat!,
                  lng: memberLng!,
                  memberName: nickname,
                ),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kAccentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: kAccentBlue,
                    size: 18,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
