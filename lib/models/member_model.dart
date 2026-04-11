import '../constants.dart';

class MemberModel {
  final String uid;
  final String nickname;
  final String vehicleType;
  final String? photoUrl;
  final bool isOnline;
  final int? joinedAt;
  final MemberRole role;

  MemberModel({
    required this.uid,
    required this.nickname,
    required this.vehicleType,
    this.photoUrl,
    this.isOnline = true,
    this.joinedAt,
    this.role = MemberRole.member,
  });

  /// Returns the VehicleInfo for this member's vehicle type.
  VehicleInfo get vehicleInfo {
    return kVehicles.firstWhere(
      (v) => v.name.toLowerCase() == vehicleType.toLowerCase(),
      orElse: () => kVehicles.first, // default to Car
    );
  }

  /// Generates initials for avatar fallback (first 2 chars of nickname).
  String get initials {
    if (nickname.isEmpty) return '??';
    final parts = nickname.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nickname.substring(0, nickname.length >= 2 ? 2 : 1).toUpperCase();
  }

  factory MemberModel.fromMap(String uid, Map<dynamic, dynamic> map) {
    return MemberModel(
      uid: uid,
      nickname: map['nickname']?.toString() ?? 'Unknown',
      vehicleType: map['vehicleType']?.toString() ?? 'Car',
      photoUrl: map['photoUrl']?.toString(),
      isOnline: map['isOnline'] == true,
      joinedAt: map['joinedAt'] is int ? map['joinedAt'] as int : null,
      role: MemberRole.fromString(map['role']?.toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'vehicleType': vehicleType,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      'joinedAt': joinedAt,
      'role': role.name,
    };
  }
}
