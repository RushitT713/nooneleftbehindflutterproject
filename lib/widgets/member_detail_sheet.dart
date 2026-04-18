import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants.dart';

/// A bottom sheet that shows detailed info for a single member in the convoy.
/// Includes actions for Kick and Transfer Host if the current user is the Host.
class MemberDetailSheet extends StatelessWidget {
  final Map<String, dynamic> memberData;
  final String uid;
  final bool isMe;
  final bool amIHost;
  final double? distanceInMeters;

  final void Function(String uid)? onKick;
  final void Function(String uid)? onTransferHost;
  final void Function(String uid)? onLocate;

  const MemberDetailSheet({
    super.key,
    required this.memberData,
    required this.uid,
    required this.isMe,
    required this.amIHost,
    this.distanceInMeters,
    this.onKick,
    this.onTransferHost,
    this.onLocate,
  });

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatJoinTime() {
    final ms = memberData['joinedAt'] as int?;
    if (ms == null) return 'Unknown';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('h:mm a').format(dt);
  }

  String _formatDistance() {
    if (distanceInMeters == null) return 'Unknown';
    if (distanceInMeters! < 1000) {
      return '${distanceInMeters!.toStringAsFixed(0)} m away';
    }
    final km = distanceInMeters! / 1000;
    return '${km.toStringAsFixed(1)} km away';
  }

  void _showConfirmDialog(
      BuildContext context, String title, String content, VoidCallback onConfirm,
      {bool isDestructive = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder), width: 1),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          content,
          style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Close bottom sheet
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? kAlertRed : kPrimary,
            ),
            child: Text(
              isDestructive ? 'Confirm Kick' : 'Confirm',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (memberData['nickname'] ?? 'Unknown').toString();
    final photo = (memberData['photoUrl'] ?? '').toString();
    final isOnline = memberData['isOnline'] == true;
    final isHost = memberData['role']?.toString() == 'host';
    final vehicle = (memberData['vehicleType'] ?? 'Car').toString();

    final vehicleInfo = kVehicles.firstWhere(
      (v) => v.name.toLowerCase() == vehicle.toLowerCase(),
      orElse: () => kVehicles.first,
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Core Info
          Stack(
            alignment: Alignment.center,
            children: [
              photo.isNotEmpty
                  ? CircleAvatar(
                      radius: 40,
                      backgroundImage: NetworkImage(photo),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    )
                  : CircleAvatar(
                      radius: 40,
                      backgroundColor: kPrimaryLight,
                      child: Text(
                        _getInitials(name),
                        style: TextStyle(
                          color: kPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                        ),
                      ),
                    ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isOnline ? kOnlineGreen : kOfflineGrey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isMe ? '$name (You)' : name,
                style: TextStyle(
                  color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
                  fontSize: 22,
                  fontFamily: 'Thicccboi',
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (isHost) ...[
                SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kPrimaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '👑 HOST',
                    style: TextStyle(
                      color: kPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 4),
          Text(
            '${vehicleInfo.emoji} Driving a ${vehicleInfo.name}',
            style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 24),

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    context,
                    Icons.access_time_rounded,
                    'Joined',
                    _formatJoinTime(),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    context,
                    Icons.route_rounded,
                    'Distance',
                    _formatDistance(),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          Divider(height: 1, color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder)),

          // Actions
          if (!isMe && onLocate != null)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kAccentBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.my_location_rounded, color: kAccentBlue),
              ),
              title: Text('Locate on Map',
                  style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary), fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                onLocate!(uid);
              },
            ),

          if (amIHost && !isMe) ...[
            Divider(height: 1, color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder)),
            if (onTransferHost != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kPrimaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.workspace_premium_rounded,
                      color: kPrimary),
                ),
                title: Text('Transfer Host Role',
                    style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary), fontWeight: FontWeight.w600)),
                onTap: () {
                  _showConfirmDialog(
                    context,
                    'Transfer Host?',
                    'Are you sure you want to make $name the new host? You will become a regular member.',
                    () => onTransferHost!(uid),
                  );
                },
              ),
            if (onKick != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kAlertRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.person_remove_rounded, color: kAlertRed),
                ),
                title: Text('Kick Member',
                    style: TextStyle(
                        color: kAlertRed, fontWeight: FontWeight.w600)),
                onTap: () {
                  _showConfirmDialog(
                    context,
                    'Kick $name?',
                    'Are you sure you want to remove $name from the convoy? They will no longer see updates.',
                    () => onKick!(uid),
                    isDestructive: true,
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatBox(BuildContext context, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary), size: 20),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
              fontFamily: 'Thicccboi',
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
