/// The type of chat message.
enum ChatMessageType {
  user,   // Regular text message typed by user
  quick,  // Quick-tap preset message
  system, // System event (join, leave, etc.)
  image,  // Shared photo
  audio;  // Voice message

  static ChatMessageType fromString(String? value) {
    switch (value) {
      case 'quick':
        return ChatMessageType.quick;
      case 'system':
        return ChatMessageType.system;
      case 'image':
        return ChatMessageType.image;
      case 'audio':
        return ChatMessageType.audio;
      default:
        return ChatMessageType.user;
    }
  }
}

class ChatMessageModel {
  final String messageId;
  final String senderId;
  final String senderName;
  final String text;
  final ChatMessageType type;
  final int timestamp;
  final String? mediaUrl;
  final int? duration;

  ChatMessageModel({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.type = ChatMessageType.user,
    required this.timestamp,
    this.mediaUrl,
    this.duration,
  });

  bool isMe(String myUid) => senderId == myUid;
  bool get isSystem => type == ChatMessageType.system;

  factory ChatMessageModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return ChatMessageModel(
      messageId: id,
      senderId: map['senderId']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? 'Unknown',
      text: map['text']?.toString() ?? '',
      type: ChatMessageType.fromString(map['type']?.toString()),
      timestamp: map['timestamp'] is int ? map['timestamp'] as int : 0,
      mediaUrl: map['mediaUrl']?.toString(),
      duration: map['duration'] is int ? map['duration'] as int : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'type': type.name,
      'timestamp': timestamp,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (duration != null) 'duration': duration,
    };
  }
}
