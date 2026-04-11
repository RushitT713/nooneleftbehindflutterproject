import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../constants.dart';
import '../models/chat_message_model.dart';

/// Service for all convoy chat Firebase RTDB operations.
class ChatService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Sends a text message to the convoy chat.
  Future<void> sendMessage({
    required String tripCode,
    required String senderId,
    required String senderName,
    required String text,
    ChatMessageType type = ChatMessageType.user,
    String? mediaUrl,
    int? duration,
  }) async {
    final ref = _db.child(chatPath(tripCode)).push();
    await ref.set({
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'type': type.name,
      'timestamp': ServerValue.timestamp,
      'mediaUrl':? mediaUrl,
      'duration':? duration,
    });
  }

  /// Sends a quick-preset message (e.g. "⛽ Need Gas").
  Future<void> sendQuickMessage({
    required String tripCode,
    required String senderId,
    required String senderName,
    required String emoji,
    required String label,
  }) async {
    await sendMessage(
      tripCode: tripCode,
      senderId: senderId,
      senderName: senderName,
      text: '$emoji $label',
      type: ChatMessageType.quick,
    );
  }

  /// Sends a system event message (e.g. "Sarah joined the convoy").
  Future<void> sendSystemMessage({
    required String tripCode,
    required String text,
  }) async {
    await sendMessage(
      tripCode: tripCode,
      senderId: 'system',
      senderName: 'System',
      text: text,
      type: ChatMessageType.system,
    );
  }

  /// Listens to all chat messages in real-time.
  /// Returns messages ordered by timestamp, limited to [kMaxChatMessages].
  Stream<List<ChatMessageModel>> listenToMessages(String tripCode) {
    final query = _db
        .child(chatPath(tripCode))
        .orderByChild('timestamp')
        .limitToLast(kMaxChatMessages);

    return query.onValue.map((event) {
      final val = event.snapshot.value;
      if (val is! Map<dynamic, dynamic>) {
        return <ChatMessageModel>[];
      }

      final messages = <ChatMessageModel>[];
      val.forEach((key, value) {
        if (value is Map) {
          messages.add(
            ChatMessageModel.fromMap(
              key.toString(),
              Map<dynamic, dynamic>.from(value),
            ),
          );
        }
      });

      // Sort by timestamp ascending (oldest first)
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return messages;
    });
  }
}
