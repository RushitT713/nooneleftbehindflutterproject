import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// COLOR PALETTE — Light Theme
// ─────────────────────────────────────────────
// Backgrounds & Surfaces
const Color kBackground    = Color(0xFFFFFFFF);  // Pure white
const Color kSurface       = Color(0xFFF5F6F8);  // Light grey cards
const Color kSurfaceBorder = Color(0xFFE8ECF0);  // Subtle card borders

// Primary (from logo green)
const Color kPrimary       = Color(0xFF5CB85C);  // Fresh green CTA
const Color kPrimaryDark   = Color(0xFF3D8B3D);  // Pressed / darker
const Color kPrimaryLight  = Color(0xFFE8F5E9);  // Very light green tint

// Accent
const Color kAccentBlue    = Color(0xFF2D8CFF);  // Links, info, "You" marker

// Text
const Color kTextPrimary   = Color(0xFF1A1A2E);  // Dark charcoal headings
const Color kTextSecondary = Color(0xFF6C757D);  // Subtitles, labels
const Color kTextTertiary  = Color(0xFF9CA3AF);  // Hints, timestamps

// Semantic
const Color kAlertRed      = Color(0xFFE53E3E);  // SOS, danger, leave
const Color kSosRed        = Color(0xFFFF1744);  // SOS pulse
const Color kOnlineGreen   = Color(0xFF38C172);  // Online status dot
const Color kSuccessGreen  = Color(0xFF38C172);  // Success, convoy secure
const Color kWarningAmber  = Color(0xFFF59E0B);  // Hazard, caution
const Color kOfflineGrey   = Color(0xFFBDBDBD);  // Offline status
const Color kHaltAmber     = Color(0xFFF5A623);  // Halt proposals

// Chat
const Color kChatSelf      = Color(0xFF2D8CFF);  // My message bubble
const Color kChatOther     = Color(0xFFF0F0F5);  // Others' message bubble
const Color kSystemMsg     = Color(0xFF9CA3AF);  // System messages

// ─────────────────────────────────────────────
// COLOR PALETTE — Dark Theme (Navy Blue & Green)
// ─────────────────────────────────────────────
const Color kDarkBackground    = Color(0xFF1A2B56);  // Navy Blue
const Color kDarkSurface       = Color(0xFF23366B);  // Lighter Navy for cards
const Color kDarkSurfaceBorder = Color(0xFF2C437F);  // Subtle card borders
const Color kDarkTextPrimary   = Color(0xFFE8E8E8);  // Light text on dark
const Color kDarkTextSecondary = Color(0xFF9CA3AF);  // Muted labels
const Color kDarkTextTertiary  = Color(0xFF6B7280);  // Hints

// Legacy aliases (for gradual migration)
const Color kDeepAsphalt   = Color(0xFF0A192F);
const Color kSkyPath       = kAccentBlue;
const Color kLimePulse     = kPrimary;
const Color kHaltYellow    = kHaltAmber;

// ─────────────────────────────────────────────
// TRIP LIMITS
// ─────────────────────────────────────────────
const int kMaxConvoyMembers = 10;
const int kMaxChatMessages = 100;
const int kMaxNicknameLength = 20;
const int kMinNicknameLength = 2;
const int kTripCodeLength = 6;

// ─────────────────────────────────────────────
// TRIP DURATIONS
// ─────────────────────────────────────────────
enum TripDuration {
  quick(label: 'Quick', hours: 2, icon: Icons.bolt),
  halfDay(label: 'Half Day', hours: 4, icon: Icons.wb_sunny_outlined),
  dayTrip(label: 'Day Trip', hours: 8, icon: Icons.wb_sunny),
  multiDay(label: 'Multi-Day', hours: 72, icon: Icons.calendar_today);

  const TripDuration({
    required this.label,
    required this.hours,
    required this.icon,
  });

  final String label;
  final int hours;
  final IconData icon;

  Duration get duration => Duration(hours: hours);
}

// ─────────────────────────────────────────────
// TRIP STATUS
// ─────────────────────────────────────────────
enum TripStatus {
  active,
  disbanded,
  expired,
  ended;

  static TripStatus fromString(String? value) {
    switch (value) {
      case 'active':
        return TripStatus.active;
      case 'disbanded':
        return TripStatus.disbanded;
      case 'expired':
        return TripStatus.expired;
      case 'ended':
        return TripStatus.ended;
      default:
        return TripStatus.active;
    }
  }
}

// ─────────────────────────────────────────────
// MEMBER ROLE
// ─────────────────────────────────────────────
enum MemberRole {
  host,
  member;

  static MemberRole fromString(String? value) {
    return value == 'host' ? MemberRole.host : MemberRole.member;
  }
}

// ─────────────────────────────────────────────
// VEHICLES
// ─────────────────────────────────────────────
class VehicleInfo {
  final String name;
  final String assetPath;
  final String emoji;

  const VehicleInfo({
    required this.name,
    required this.assetPath,
    required this.emoji,
  });
}

const List<VehicleInfo> kVehicles = [
  VehicleInfo(name: 'Car', assetPath: 'assets/images/car.png', emoji: '🚗'),
  VehicleInfo(name: 'Bike', assetPath: 'assets/images/bike.png', emoji: '🏍️'),
  VehicleInfo(name: 'SUV', assetPath: 'assets/images/suv.png', emoji: '🚙'),
  VehicleInfo(name: 'Van', assetPath: 'assets/images/van.png', emoji: '🚐'),
];

// ─────────────────────────────────────────────
// FIREBASE RTDB PATHS
// ─────────────────────────────────────────────
const String kTripsPath = 'trips';

String tripPath(String code) => '$kTripsPath/$code';
String metadataPath(String code) => '$kTripsPath/$code/metadata';
String membersPath(String code) => '$kTripsPath/$code/members';
String memberPath(String code, String uid) => '$kTripsPath/$code/members/$uid';
String liveLocationsPath(String code) => '$kTripsPath/$code/live_locations';
String liveLocationPath(String code, String uid) =>
    '$kTripsPath/$code/live_locations/$uid';
String chatPath(String code) => '$kTripsPath/$code/chat';
String haltsPath(String code) => '$kTripsPath/$code/halts';
String haltPath(String code, String haltId) =>
    '$kTripsPath/$code/halts/$haltId';
String sosPath(String code) => '$kTripsPath/$code/sos';

// ─────────────────────────────────────────────
// SOS REASONS
// ─────────────────────────────────────────────
enum SosReason {
  accident('Accident', Icons.car_crash, '🚨'),
  breakdown('Breakdown', Icons.build, '🔧'),
  medical('Medical Emergency', Icons.local_hospital, '🏥'),
  tyrePuncture('Tyre Puncture', Icons.tire_repair, '🛞'),
  lost('Lost / Separated', Icons.explore_off, '🧭'),
  other('Other', Icons.warning_amber, '⚠️');

  const SosReason(this.label, this.icon, this.emoji);

  final String label;
  final IconData icon;
  final String emoji;
}

// ─────────────────────────────────────────────
// QUICK CHAT MESSAGES
// ─────────────────────────────────────────────
const List<Map<String, String>> kQuickMessages = [
  {'emoji': '👍', 'text': 'On my way!'},
  {'emoji': '⛽', 'text': 'Need fuel stop'},
  {'emoji': '🚻', 'text': 'Restroom break needed'},
  {'emoji': '🍔', 'text': 'Hungry, need food'},
  {'emoji': '⚠️', 'text': 'Police ahead'},
  {'emoji': '🐌', 'text': 'Heavy traffic'},
  {'emoji': '🛞', 'text': 'Tyre issue'},
  {'emoji': '✅', 'text': 'I am here'},
  {'emoji': '⏳', 'text': 'Running late'},
  {'emoji': '📍', 'text': 'Where are you?'},
];

// ─────────────────────────────────────────────
// LOCATION UPDATE INTERVALS (seconds)
// ─────────────────────────────────────────────
const int kHighAccuracyInterval = 3; // Moving >5 km/h
const int kMediumInterval = 10; // Slow 0-5 km/h
const int kLowInterval = 60; // Stationary
const int kParkingInterval = 300; // Parking mode (5 min)

// Speed thresholds (km/h)
const double kMovingSpeedThreshold = 5.0;
const double kSlowSpeedThreshold = 0.5;

// ─────────────────────────────────────────────
// HALT STATUS
// ─────────────────────────────────────────────
enum HaltStatus {
  active,
  resolved,
  cancelled;

  static HaltStatus fromString(String? value) {
    switch (value) {
      case 'resolved':
        return HaltStatus.resolved;
      case 'cancelled':
        return HaltStatus.cancelled;
      default:
        return HaltStatus.active;
    }
  }
}

// ─────────────────────────────────────────────
// HALT VOTE
// ─────────────────────────────────────────────
enum HaltVote {
  yes('Yes', '✓'),
  no('No', '✗'),
  maybe('Maybe', '⏸️');

  const HaltVote(this.label, this.symbol);

  final String label;
  final String symbol;
}
