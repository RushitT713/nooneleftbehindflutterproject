import 'dart:async';
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/chat_message_model.dart';
import '../providers/trip_provider.dart';
import '../services/connectivity_service.dart';
import '../services/chat_service.dart';
import '../services/audio_service.dart';

/// Convoy Quick Chat — functional real-time chat via Firebase RTDB.
class ChatScreen extends StatefulWidget {
  final String tripCode;

  const ChatScreen({super.key, required this.tripCode});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final AudioService _audioService = AudioService();

  List<ChatMessageModel> _messages = [];
  StreamSubscription? _chatSubscription;
  StreamSubscription<bool>? _conSub;

  bool _isRecording = false;
  bool _isUploading = false;
  String? _uploadStatusText;
  bool _isOnline = true;

  // --- CLOUDINARY CONFIGURATION ---
  // Reusing the same Cloudinary instance used in profile setup
  final cloudinary = CloudinaryPublic(
    'dngsod1g2',
    'no_one_left_behind',
    cache: false,
  );

  // Quick Chat Presets
  static const List<_QuickPreset> _quickPresets = [
    _QuickPreset(emoji: '⛽', label: 'Need Gas', color: kAccentBlue),
    _QuickPreset(emoji: '🍔', label: 'Hungry', color: kWarningAmber),
    _QuickPreset(emoji: '🚨', label: 'Police', color: kAlertRed),
    _QuickPreset(emoji: '👍', label: 'All Good', color: kSuccessGreen),
    _QuickPreset(emoji: '🚻', label: 'Restroom', color: kAccentBlue),
    _QuickPreset(emoji: '⏳', label: 'Running Late', color: kWarningAmber),
  ];

  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityService().isOnline;
    _conSub = ConnectivityService().onConnectivityChanged.listen((val) {
      if (mounted) setState(() => _isOnline = val);
    });
    _startListening();
  }

  void _startListening() {
    _chatSubscription = _chatService
        .listenToMessages(widget.tripCode)
        .listen((messages) {
      if (!mounted) return;
      setState(() => _messages = messages);
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    final provider = context.read<TripProvider>();
    final userId = provider.userId ?? '';
    final nickname = provider.nickname ?? 'Unknown';

    _chatService.sendMessage(
      tripCode: widget.tripCode,
      senderId: userId,
      senderName: nickname,
      text: text.trim(),
    );

    _messageController.clear();
  }

  void _sendQuickMessage(String emoji, String label) {
    final provider = context.read<TripProvider>();
    final userId = provider.userId ?? '';
    final nickname = provider.nickname ?? 'Unknown';

    _chatService.sendQuickMessage(
      tripCode: widget.tripCode,
      senderId: userId,
      senderName: nickname,
      emoji: emoji,
      label: label,
    );
  }

  // ─── Media Handling ──────────────────────────────

  Future<void> _pickAndSendImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image != null) {
      await _uploadAndSendMedia(File(image.path), ChatMessageType.image);
    }
  }

  void _onRecordStart() async {
    setState(() => _isRecording = true);
    await _audioService.startRecording();
  }

  void _onRecordStop() async {
    final result = await _audioService.stopRecording();
    setState(() => _isRecording = false);
    
    if (result != null && result['path'] != null) {
      final duration = result['duration'] as int;
      if (duration > 500) { // Ignore tiny accidental taps
        await _uploadAndSendMedia(File(result['path']), ChatMessageType.audio, duration: duration);
      }
    }
  }

  Future<void> _uploadAndSendMedia(File file, ChatMessageType type, {int? duration}) async {
    setState(() {
      _isUploading = true;
      _uploadStatusText = type == ChatMessageType.image ? 'Sending photo...' : 'Sending voice message...';
    });

    final provider = context.read<TripProvider>();
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(file.path, folder: 'chat_media', resourceType: type == ChatMessageType.audio ? CloudinaryResourceType.Video : CloudinaryResourceType.Image),
      );

      final String url = response.secureUrl;
      
      await _chatService.sendMessage(
        tripCode: widget.tripCode,
        senderId: provider.userId ?? '',
        senderName: provider.nickname ?? 'Unknown',
        text: type == ChatMessageType.image ? 'Sent a photo' : 'Sent a voice message',
        type: type,
        mediaUrl: url,
        duration: duration,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatusText = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _conSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final myUserId = provider.userId ?? '';
    final memberCount = provider.memberCount;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'Convoy Chat',
              style: TextStyle(
                fontFamily: 'Thicccboi',
                fontWeight: FontWeight.w900,
                color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
                fontSize: 18,
              ),
            ),
            Text(
              '$memberCount member${memberCount == 1 ? '' : 's'} • ${_messages.length} messages',
              style: TextStyle(
                color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.people_outline, color: kAccentBlue),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Divider
          Container(height: 1, color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder)),
          
          if (!_isOnline)
            Container(
              width: double.infinity,
              color: kWarningAmber.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.wifi_off, color: kWarningAmber, size: 14),
                   SizedBox(width: 8),
                   Text(
                     'Working Offline - Messages will send later',
                     style: TextStyle(color: kWarningAmber, fontSize: 11, fontWeight: FontWeight.bold),
                   ),
                ],
              ),
            ),

          // Messages List
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary).withValues(alpha: 0.4),
                            size: 48),
                        SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
                            fontFamily: 'Thicccboi',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Send a message or tap a quick preset!',
                          style: TextStyle(
                            color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessage(msg, myUserId);
                    },
                  ),
          ),

          // Quick Message Chips
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickPresets.length,
              separatorBuilder: (_, _) => SizedBox(width: 8),
              itemBuilder: (context, index) {
                final preset = _quickPresets[index];
                return GestureDetector(
                  onTap: () => _sendQuickMessage(preset.emoji, preset.label),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(preset.emoji,
                            style: TextStyle(fontSize: 16)),
                        SizedBox(width: 6),
                        Text(
                          preset.label,
                          style: TextStyle(
                            fontFamily: 'Thicccboi',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: preset.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 8),

          // Input Bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder))),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                        // Attach button
                  GestureDetector(
                    onTap: _isUploading ? null : _pickAndSendImage,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder)),
                      ),
                      child: Icon(Icons.add,
                          color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextSecondary : kTextSecondary), size: 22),
                    ),
                  ),
                  SizedBox(width: 10),

                  // Text Field
                  Expanded(
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder)),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(
                          color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Message convoy...',
                          hintStyle: TextStyle(
                              color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary), fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),

                  // Mic icon
                  GestureDetector(
                    onLongPress: _isUploading ? null : _onRecordStart,
                    onLongPressUp: _isUploading ? null : _onRecordStop,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _isRecording ? kAlertRed.withValues(alpha: 0.1) : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.mic,
                          color: _isRecording ? kAlertRed : (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary), size: _isRecording ? 28 : 24),
                    ),
                  ),
                  SizedBox(width: 8),

                  // Send button
                  GestureDetector(
                    onTap: () => _sendMessage(_messageController.text),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: kAccentBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.send,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Uploading Indicator
          if (_isUploading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              width: double.infinity,
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(kAccentBlue)),
                  ),
                  SizedBox(width: 8),
                  Text(
                    _uploadStatusText ?? 'Uploading...', 
                    style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary), fontSize: 12, fontWeight: FontWeight.w500)
                  )
                ],
              )
            )
        ],
      ),
    );
  }

  // ─── Message Rendering ──────────────────────────

  Widget _buildMessage(ChatMessageModel msg, String myUserId) {
    if (msg.isSystem) {
      return _buildSystemMessage(msg);
    } else if (msg.isMe(myUserId)) {
      return _buildMyMessage(msg);
    } else if (msg.type == ChatMessageType.quick) {
      return _buildOtherMessage(msg);
    } else {
      return _buildOtherMessage(msg);
    }
  }

  Widget _buildSystemMessage(ChatMessageModel msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder)),
          ),
          child: Text(
            msg.text,
            style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyMessage(ChatMessageModel msg) {
    final timeStr = _formatTimestamp(msg.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (msg.type == ChatMessageType.image && msg.mediaUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                msg.mediaUrl!,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, prog) => prog == null ? child : SizedBox(width: 200, height: 200, child: Center(child: CircularProgressIndicator())),
                errorBuilder: (_, _, _) => SizedBox(width: 200, height: 200, child: Center(child: Icon(Icons.broken_image, color: Colors.white54))),
              ),
            ),
          ] else if (msg.type == ChatMessageType.audio && msg.mediaUrl != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: kAccentBlue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: _AudioPlayerWidget(
                url: msg.mediaUrl!, 
                duration: msg.duration ?? 0, 
                isMe: true
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: kAccentBlue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
          SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (msg.timestamp == 0) ...[
                Icon(Icons.access_time, size: 10, color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary)),
                SizedBox(width: 4),
              ],
              Text(
                timeStr,
                style: TextStyle(
                  color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildOtherMessage(ChatMessageModel msg) {
    final timeStr = _formatTimestamp(msg.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4, right: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            msg.senderName,
            style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: kPrimaryLight,
                child: Text(
                  msg.senderName.isNotEmpty ? msg.senderName[0] : '?',
                  style: TextStyle(
                    color: kPrimary,
                    fontFamily: 'Thicccboi',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Flexible(
                child: () {
                  if (msg.type == ChatMessageType.image && msg.mediaUrl != null) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        msg.mediaUrl!,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, prog) => prog == null ? child : SizedBox(width: 200, height: 200, child: Center(child: CircularProgressIndicator())),
                        errorBuilder: (_, _, _) => SizedBox(width: 200, height: 200, child: Center(child: Icon(Icons.broken_image, color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary)))),
                      ),
                    );
                  } else {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(18),
                        ),
                      ),
                      child: (msg.type == ChatMessageType.audio && msg.mediaUrl != null)
                          ? _AudioPlayerWidget(
                              url: msg.mediaUrl!,
                              duration: msg.duration ?? 0,
                              isMe: false)
                          : Text(
                              msg.text,
                              style: TextStyle(
                                color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary),
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                    );
                  }
                }(),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 40, top: 4),
            child: Text(
              timeStr,
              style: TextStyle(
                color: (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
                fontSize: 11,
              ),
            ),
          ),
          SizedBox(height: 12),
        ],
      ),
    );
  }

  /// Formats a Firebase timestamp (ms since epoch) to a readable time string.
  String _formatTimestamp(int timestamp) {
    if (timestamp == 0) return 'Sending...';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';

    if (dt.day == now.day &&
        dt.month == now.month &&
        dt.year == now.year) {
      return '$hour:$minute $amPm';
    }
    return '${dt.day}/${dt.month} $hour:$minute $amPm';
  }
}

// ─── Quick Preset Data ────────────────────────────

class _QuickPreset {
  final String emoji;
  final String label;
  final Color color;

  const _QuickPreset({
    required this.emoji,
    required this.label,
    required this.color,
  });
}

// ─── Audio Player Widget ────────────────────────────

class _AudioPlayerWidget extends StatefulWidget {
  final String url;
  final int duration; // in milliseconds
  final bool isMe;

  const _AudioPlayerWidget({
    required this.url,
    required this.duration,
    required this.isMe,
  });

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  final AudioService _audioService = AudioService();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;

  @override
  void initState() {
    super.initState();
    _playerStateSub = _audioService.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.toString().contains('playing');
        });
      }
    });

    _positionSub = _audioService.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
        });
      }
    });
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _audioService.pauseAudio();
    } else {
      await _audioService.playAudio(widget.url);
    }
  }

  String _formatDuration(int milliseconds) {
    if (milliseconds == 0) return '0:00';
    final seconds = (milliseconds / 1000).round();
    final s = seconds % 60;
    final m = (seconds / 60).floor();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final totalDurationStr = _formatDuration(widget.duration);
    final posStr = _formatDuration(_position.inMilliseconds);
    final displayStr = _isPlaying ? posStr : totalDurationStr;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Icon(
            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: widget.isMe ? Colors.white : kAccentBlue,
            size: 32,
          ),
        ),
        SizedBox(width: 8),
        Container(
          width: 80,
          height: 4,
          decoration: BoxDecoration(
            color: widget.isMe ? Colors.white38 : (Theme.of(context).brightness == Brightness.dark ? kDarkSurfaceBorder : kSurfaceBorder),
            borderRadius: BorderRadius.circular(2),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: widget.duration > 0 ? (_position.inMilliseconds / widget.duration).clamp(0.0, 1.0) : 0,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: widget.isMe ? Colors.white : kAccentBlue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        Text(
          displayStr,
          style: TextStyle(
            color: widget.isMe ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? kDarkTextTertiary : kTextTertiary),
            fontSize: 12,
            fontFamily: 'Thicccboi',
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
