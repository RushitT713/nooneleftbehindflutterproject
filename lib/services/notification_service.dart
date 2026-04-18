import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Singleton service for local push notifications.
/// No Firebase Cloud Messaging required — all notifications are triggered
/// locally when the app detects convoy events from RTDB streams.
class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Notification Channel IDs ────────────────────
  static const String _sosChannelId = 'nolb_sos';
  static const String _sosChannelName = 'SOS Alerts';
  static const String _sosChannelDesc =
      'Critical emergency alerts from convoy members';

  static const String _convoyChannelId = 'nolb_convoy';
  static const String _convoyChannelName = 'Convoy Updates';
  static const String _convoyChannelDesc =
      'Member joins, leaves, and convoy status changes';

  static const String _chatChannelId = 'nolb_chat';
  static const String _chatChannelName = 'Chat Messages';
  static const String _chatChannelDesc =
      'New messages from convoy members';

  static const String _haltChannelId = 'nolb_halt';
  static const String _haltChannelName = 'Halt Proposals';
  static const String _haltChannelDesc =
      'Halt stop proposals from convoy members';

  // ── Notification IDs (unique per type) ──────────
  // Using fixed IDs so repeated events of the same type replace each other
  static const int _sosNotifId = 1000;
  static const int _memberJoinNotifId = 2000;
  static const int _memberLeaveNotifId = 2001;
  static const int _haltNotifId = 3000;
  static const int _chatNotifId = 4000;
  static const int _tripEndNotifId = 5000;

  /// Initializes the notification plugin. Call once at app startup.
  Future<void> init() async {
    if (_initialized) return;

    // Android initialization
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
    debugPrint('NotificationService initialized');
  }

  /// Requests notification permissions (required for Android 13+).
  Future<void> requestPermission() async {
    final bool? granted = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    debugPrint('Notification permission granted: $granted');
  }

  /// Called when user taps a notification.
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // The app is already open or will be brought to foreground.
    // No extra navigation needed — user is already in the convoy.
  }

  // ══════════════════════════════════════════════
  // PUBLIC API — Call these from your screens/providers
  // ══════════════════════════════════════════════

  /// 🚨 SOS Alert — highest priority, plays default alarm sound.
  Future<void> showSosNotification({
    required String memberName,
    required String reason,
    String? note,
  }) async {
    final body = note != null && note.isNotEmpty
        ? '$memberName: $reason — "$note"'
        : '$memberName triggered $reason';

    await _show(
      id: _sosNotifId,
      channelId: _sosChannelId,
      channelName: _sosChannelName,
      channelDesc: _sosChannelDesc,
      title: '🚨 SOS ALERT',
      body: body,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      payload: 'sos',
    );
  }

  /// 👋 Member joined the convoy.
  Future<void> showMemberJoinedNotification({
    required String memberName,
    required String vehicleType,
  }) async {
    await _show(
      id: _memberJoinNotifId,
      channelId: _convoyChannelId,
      channelName: _convoyChannelName,
      channelDesc: _convoyChannelDesc,
      title: '👋 New Member Joined',
      body: '$memberName joined the convoy ($vehicleType)',
      importance: Importance.high,
      priority: Priority.high,
      payload: 'member_joined',
    );
  }

  /// 🚪 Member left the convoy.
  Future<void> showMemberLeftNotification({
    required String memberName,
  }) async {
    await _show(
      id: _memberLeaveNotifId,
      channelId: _convoyChannelId,
      channelName: _convoyChannelName,
      channelDesc: _convoyChannelDesc,
      title: '🚪 Member Left',
      body: '$memberName has left the convoy',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      payload: 'member_left',
    );
  }

  /// 🛑 Halt proposal from a convoy member.
  Future<void> showHaltNotification({
    required String proposerName,
    required String locationName,
    String? note,
  }) async {
    final body = note != null && note.isNotEmpty
        ? '$proposerName wants to stop at $locationName — "$note"'
        : '$proposerName wants to stop at $locationName';

    await _show(
      id: _haltNotifId,
      channelId: _haltChannelId,
      channelName: _haltChannelName,
      channelDesc: _haltChannelDesc,
      title: '🛑 Halt Proposed',
      body: body,
      importance: Importance.high,
      priority: Priority.high,
      payload: 'halt',
    );
  }

  /// 💬 New chat message (only when not on chat screen).
  Future<void> showChatNotification({
    required String senderName,
    required String message,
  }) async {
    await _show(
      id: _chatNotifId,
      channelId: _chatChannelId,
      channelName: _chatChannelName,
      channelDesc: _chatChannelDesc,
      title: '💬 $senderName',
      body: message,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      payload: 'chat',
    );
  }

  /// 🏁 Trip ended.
  Future<void> showTripEndedNotification() async {
    await _show(
      id: _tripEndNotifId,
      channelId: _convoyChannelId,
      channelName: _convoyChannelName,
      channelDesc: _convoyChannelDesc,
      title: '🏁 Convoy Ended',
      body: 'The convoy has been ended by the host. Safe travels!',
      importance: Importance.high,
      priority: Priority.high,
      payload: 'trip_ended',
    );
  }

  /// Cancels all active notifications (e.g., when leaving a trip).
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ══════════════════════════════════════════════
  // PRIVATE — builds and shows the actual notification
  // ══════════════════════════════════════════════

  Future<void> _show({
    required int id,
    required String channelId,
    required String channelName,
    required String channelDesc,
    required String title,
    required String body,
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
    bool playSound = true,
    bool enableVibration = true,
    String? payload,
  }) async {
    if (!_initialized) {
      debugPrint('NotificationService: not initialized, skipping notification');
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: importance,
      priority: priority,
      playSound: playSound,
      enableVibration: enableVibration,
      icon: '@mipmap/launcher_icon',
      styleInformation: BigTextStyleInformation(body),
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(id, title, body, details, payload: payload);
  }
}
