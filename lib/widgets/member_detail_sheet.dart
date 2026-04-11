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
        backgroundColor: kBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kSurfaceBorder, width: 1),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          content,
          style: const TextStyle(color: kTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: kTextTertiary)),
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
              style: const TextStyle(color: Colors.white),
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
      decoration: const BoxDecoration(
        color: kBackground,
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
                color: kSurfaceBorder.withValues(alpha: 0.5),
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
                      backgroundColor: kSurface,
                    )
                  : CircleAvatar(
                      radius: 40,
                      backgroundColor: kPrimaryLight,
                      child: Text(
                        _getInitials(name),
                        style: const TextStyle(
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
                    border: Border.all(color: kBackground, width: 3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isMe ? '$name (You)' : name,
                style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 22,
                  fontFamily: 'Thicccboi',
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (isHost) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kPrimaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
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
          const SizedBox(height: 4),
          Text(
            '${vehicleInfo.emoji} Driving a ${vehicleInfo.name}',
            style: const TextStyle(
              color: kTextSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    Icons.access_time_rounded,
                    'Joined',
                    _formatJoinTime(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    Icons.route_rounded,
                    'Distance',
                    _formatDistance(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: kSurfaceBorder),

          // Actions
          if (!isMe && onLocate != null)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kAccentBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.my_location_rounded, color: kAccentBlue),
              ),
              title: const Text('Locate on Map',
                  style: TextStyle(
                      color: kTextPrimary, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                onLocate!(uid);
              },
            ),

          if (amIHost && !isMe) ...[
            const Divider(height: 1, color: kSurfaceBorder),
            if (onTransferHost != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kPrimaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: kPrimary),
                ),
                title: const Text('Transfer Host Role',
                    style: TextStyle(
                        color: kTextPrimary, fontWeight: FontWeight.w600)),
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
                  child: const Icon(Icons.person_remove_rounded, color: kAlertRed),
                ),
                title: const Text('Kick Member',
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

  Widget _buildStatBox(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSurfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kTextTertiary, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: kTextPrimary,
              fontFamily: 'Thicccboi',
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: kTextTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
