import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants.dart';
import '../models/trip_model.dart';
import '../providers/theme_provider.dart';
import '../services/shake_detector_service.dart';
import '../utils/navigation_utils.dart';
import '../widgets/member_detail_sheet.dart';
import 'package:geolocator/geolocator.dart';

/// Full-featured convoy drawer — profile, roster, parking, shake sensitivity.
class ConvoyDrawer extends StatelessWidget {
  final String? myUserId;
  final String? nickname;
  final String? vehicleType;
  final String? photoUrl;
  final String? tripCode;
  final bool isHost;
  final bool isParkingMode;
  final Map<String, Map<String, dynamic>> members;
  final Map<String, Map<String, dynamic>> locations;
  final ShakeDetectorService shakeDetector;
  final VoidCallback onParkingToggle;
  final void Function(String uid) onLocateMember;
  final TripDestination? destination;
  final void Function()? onSetDestination;
  final void Function()? onClearDestination;
  final void Function(String)? onKickMember;
  final void Function(String)? onTransferHost;

  const ConvoyDrawer({
    super.key,
    required this.myUserId,
    required this.nickname,
    required this.vehicleType,
    required this.photoUrl,
    required this.tripCode,
    required this.isHost,
    required this.isParkingMode,
    required this.members,
    required this.locations,
    required this.shakeDetector,
    required this.onParkingToggle,
    required this.onLocateMember,
    this.destination,
    this.onSetDestination,
    this.onClearDestination,
    this.onKickMember,
    this.onTransferHost,
  });

  @override
  Widget build(BuildContext context) {
    final vehicleInfo = kVehicles.firstWhere(
      (v) => v.name.toLowerCase() == (vehicleType ?? 'car').toLowerCase(),
      orElse: () => kVehicles.first,
    );

    // Sort members: self first, then alphabetically
    final sortedMembers = members.entries.toList()
      ..sort((a, b) {
        if (a.key == myUserId) return -1;
        if (b.key == myUserId) return 1;
        final nameA = (a.value['nickname'] ?? '').toString();
        final nameB = (b.value['nickname'] ?? '').toString();
        return nameA.compareTo(nameB);
      });

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── PROFILE HEADER ────────────────────────
            _buildProfileHeader(context, vehicleInfo),

            Divider(color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder), height: 1),

            // ── SCROLLABLE CONTENT ────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // ── TRIP CODE SECTION ─────────────────
                  _buildTripCodeSection(context),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder), height: 24),
                  ),

                  // ── CONVOY ROSTER ─────────────────────
                  _buildSectionHeader(context, 'CONVOY ROSTER', '${members.length}'),
                  SizedBox(height: 4),
                  ...sortedMembers.map((entry) =>
                      _buildMemberTile(context, entry.key, entry.value)),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder), height: 24),
                  ),

                  // ── PARKING MODE ──────────────────────
                  _buildParkingToggle(context),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder), height: 24),
                  ),

                  // ── DESTINATION ─────────────────────────
                  _buildDestinationSection(context),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder), height: 24),
                  ),

                  // ── SHAKE SENSITIVITY ─────────────────
                  _buildShakeSensitivity(context),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder), height: 24),
                  ),

                  // ── MAP NIGHT MODE ─────────────────────────
                  _buildNightModeToggle(context),

                  SizedBox(height: 16),

                  // ── APP DARK MODE ─────────────────────────
                  _buildAppThemeToggle(context),

                  SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Profile Header ────────────────────────────────
  Widget _buildProfileHeader(BuildContext context, VehicleInfo vehicleInfo) {
    final initials = _getInitials(nickname ?? '');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          // Avatar
          (photoUrl ?? '').isNotEmpty
              ? CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(photoUrl!),
                  onBackgroundImageError: (e, _) {},
                  backgroundColor: Theme.of(context).colorScheme.surface,
                )
              : CircleAvatar(
                  radius: 28,
                  backgroundColor: kPrimaryLight,
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
          SizedBox(width: 14),

          // Name + Vehicle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname ?? 'Unknown',
                  style: TextStyle(
                    color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
                    fontFamily: 'Thicccboi',
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      vehicleInfo.emoji,
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Driving a ${vehicleInfo.name}',
                      style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Role badge
          if (isHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kPrimaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'HOST',
                style: TextStyle(
                  color: kPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Trip Code Section ─────────────────────────────
  Widget _buildTripCodeSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TRIP CODE',
              style: TextStyle(
                color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tripCode ?? '------',
                      style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
                        fontSize: 24,
                        fontFamily: 'Thicccboi',
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // Copy button
                _SmallActionButton(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  onTap: () {
                    if (tripCode != null) {
                      Clipboard.setData(ClipboardData(text: tripCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Trip code copied!'),
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
                ),
                SizedBox(width: 8),
                // Share button
                _SmallActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: () {
                    if (tripCode != null) {
                      SharePlus.instance.share(
                        ShareParams(
                          text:
                              'Join my convoy on NoOneLeftBehind!\nTrip Code: $tripCode',
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Section Header ────────────────────────────────
  Widget _buildSectionHeader(BuildContext context, String title, String badge) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
              fontSize: 11,
              fontFamily: 'Thicccboi',
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: kPrimaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: kPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Member Tile ───────────────────────────────────
  Widget _buildMemberTile(
      BuildContext context, String uid, Map<String, dynamic> data) {
    final name = (data['nickname'] ?? 'Unknown').toString();
    final isOnline = data['isOnline'] == true;
    final isMe = uid == myUserId;
    final vehicle = (data['vehicleType'] ?? 'Car').toString();
    final photo = (data['photoUrl'] ?? '').toString();
    final hasLocation = locations.containsKey(uid);

    final vehicleInfo = kVehicles.firstWhere(
      (v) => v.name.toLowerCase() == vehicle.toLowerCase(),
      orElse: () => kVehicles.first,
    );

    final initials = _getInitials(name);

    final isHostMember = data['role']?.toString() == MemberRole.host.name;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context); // Close drawer
          double? dist;
          if (hasLocation && locations.containsKey(myUserId)) {
            final myLoc = locations[myUserId]!;
            final theirLoc = locations[uid]!;
            dist = Geolocator.distanceBetween(
              myLoc['lat'], myLoc['lng'],
              theirLoc['lat'], theirLoc['lng'],
            );
          }
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => MemberDetailSheet(
              memberData: data,
              uid: uid,
              isMe: isMe,
              amIHost: isHost,
              distanceInMeters: dist,
              onKick: onKickMember,
              onTransferHost: onTransferHost,
              onLocate: hasLocation ? onLocateMember : null,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              // Avatar with online dot
              Stack(
                children: [
                  photo.isNotEmpty
                      ? CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(photo),
                          onBackgroundImageError: (e, _) {},
                          backgroundColor: Theme.of(context).colorScheme.surface,
                        )
                      : CircleAvatar(
                          radius: 18,
                          backgroundColor: kPrimaryLight,
                          child: Text(
                            initials,
                            style: TextStyle(
                              color: kPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
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
                        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12),

              // Name + vehicle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isMe ? '$name (You)' : name,
                            style: TextStyle(
                              color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
                              fontWeight:
                                  isMe ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isHostMember) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: kWarningAmber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: kWarningAmber.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, color: kWarningAmber, size: 10),
                                const SizedBox(width: 2),
                                Text(
                                  'Host',
                                  style: TextStyle(
                                    color: kWarningAmber,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Thicccboi',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${vehicleInfo.emoji} ${vehicleInfo.name}',
                      style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              if (!hasLocation)
                Text(
                  'No GPS',
                  style: TextStyle(color: kOfflineGrey, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Parking Mode Toggle ───────────────────────────
  Widget _buildParkingToggle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isParkingMode
              ? kHaltAmber.withValues(alpha: 0.08)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isParkingMode
                ? kHaltAmber.withValues(alpha: 0.3)
                : (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isParkingMode
                    ? kHaltAmber.withValues(alpha: 0.15)
                    : (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '🅿️',
                style: TextStyle(fontSize: isParkingMode ? 20 : 18),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Parking Mode',
                    style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
                      fontFamily: 'Thicccboi',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    isParkingMode
                        ? 'GPS updates paused — saving battery'
                        : 'Turn on when parked to save battery',
                    style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: isParkingMode,
              onChanged: (_) => onParkingToggle(),
              activeTrackColor: kHaltAmber.withValues(alpha: 0.3),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return kHaltAmber;
                }
                return null;
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Destination Section ───────────────────────────
  Widget _buildDestinationSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary), size: 18),
              SizedBox(width: 8),
              Text(
                'DESTINATION',
                style: TextStyle(
                  color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
                  fontSize: 11,
                  fontFamily: 'Thicccboi',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          if (destination != null) ...[
            // Show current destination
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? kPrimary.withValues(alpha: 0.15) : kPrimaryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrimary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place, color: kPrimary, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          destination!.name,
                          style: TextStyle(
                            color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
                            fontFamily: 'Thicccboi',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      // Navigate button
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            final myLoc = locations[myUserId];
                            if (myLoc != null) {
                              NavigationUtils.openRouteInGoogleMaps(
                                originLat: myLoc['lat'].toDouble(),
                                originLng: myLoc['lng'].toDouble(),
                                destLat: destination!.lat,
                                destLng: destination!.lng,
                              );
                            } else {
                              NavigationUtils.navigateToMember(
                                lat: destination!.lat,
                                lng: destination!.lng,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: kPrimary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.navigation_rounded,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Navigate',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Clear button (Host only)
                      if (isHost && onClearDestination != null) ...[
                        SizedBox(width: 8),
                        GestureDetector(
                          onTap: onClearDestination,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: kAlertRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.close,
                                color: kAlertRed, size: 18),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            // No destination yet
            if (isHost && onSetDestination != null)
              GestureDetector(
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  onSetDestination!();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.add_location_alt_rounded,
                          color: kPrimary, size: 24),
                      SizedBox(height: 4),
                      Text(
                        'Set Destination',
                        style: TextStyle(
                          color: kPrimary,
                          fontFamily: 'Thicccboi',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Long-press on map or search here',
                        style: TextStyle(
                          color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(
                'No destination set by the host.',
                style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary), fontSize: 12),
              ),
          ],
        ],
      ),
    );
  }

  // ── Shake Sensitivity ─────────────────────────────
  Widget _buildShakeSensitivity(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.vibration, color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'SOS SHAKE SENSITIVITY',
                    style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
                      fontSize: 11,
                      fontFamily: 'Thicccboi',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: ShakeSensitivity.values.map((level) {
                  final isSelected = shakeDetector.sensitivity == level;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        shakeDetector.setSensitivity(level);
                        setLocalState(() {});
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? (Theme.of(context).brightness == Brightness.dark ? kPrimary.withValues(alpha: 0.15) : kPrimaryLight) 
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? kPrimary : (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              level == ShakeSensitivity.low
                                  ? Icons.shield_outlined
                                  : level == ShakeSensitivity.medium
                                      ? Icons.tune
                                      : Icons.bolt,
                              color:
                                  isSelected ? kPrimary : (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
                              size: 20,
                            ),
                            SizedBox(height: 4),
                            Text(
                              level.label,
                              style: TextStyle(
                                fontFamily: 'Thicccboi',
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 12,
                                color: isSelected
                                    ? kPrimary
                                    : (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 6),
              Text(
                shakeDetector.sensitivity == ShakeSensitivity.low
                    ? 'Harder to trigger — less false alarms'
                    : shakeDetector.sensitivity == ShakeSensitivity.high
                        ? 'Easier to trigger — more responsive'
                        : 'Balanced — recommended setting',
                style: TextStyle(
                  color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Map Night Mode Toggle ─────────────────────────
  Widget _buildNightModeToggle(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isMapNightMode = themeProvider.isMapNightMode;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMapNightMode
                  ? kPrimary.withValues(alpha: 0.08)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isMapNightMode
                    ? kPrimary.withValues(alpha: 0.3)
                    : (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMapNightMode
                        ? kPrimary.withValues(alpha: 0.15)
                        : (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isMapNightMode ? Icons.map : Icons.map_outlined,
                    color: isMapNightMode ? kPrimary : (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary),
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Night Mode',
                        style: TextStyle(
                          color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
                          fontFamily: 'Thicccboi',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        isMapNightMode
                            ? 'Dark map for night driving'
                            : 'Enable dark map filter',
                        style: TextStyle(
                          color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isMapNightMode,
                  onChanged: (value) {
                    themeProvider.toggleMapNightMode();
                  },
                  activeTrackColor: kPrimary.withValues(alpha: 0.3),
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return kPrimary;
                    }
                    return null;
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── App Dark Mode Toggle ─────────────────────────
  Widget _buildAppThemeToggle(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDarkMode = themeProvider.isDark;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? kPrimary.withValues(alpha: 0.08)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDarkMode
                    ? kPrimary.withValues(alpha: 0.3)
                    : (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? kPrimary.withValues(alpha: 0.15)
                        : (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isDarkMode ? Icons.dark_mode : Icons.dark_mode_outlined,
                    color: isDarkMode ? kPrimary : (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary),
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dark Mode',
                        style: TextStyle(
                          color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
                          fontFamily: 'Thicccboi',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        isDarkMode
                            ? 'Using Navy Blue dark theme'
                            : 'Enable dark theme',
                        style: TextStyle(
                          color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isDarkMode,
                  onChanged: (value) {
                    themeProvider.toggleAppTheme();
                  },
                  activeTrackColor: kPrimary.withValues(alpha: 0.3),
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return kPrimary;
                    }
                    return null;
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────
  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ── Small Action Button ─────────────────────────────
class _SmallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: kPrimaryLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kPrimary, size: 14),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: kPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
