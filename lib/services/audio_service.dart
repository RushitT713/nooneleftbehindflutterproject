import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Service to handle voice recording and playback in the chat.
class AudioService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String? _currentRecordingPath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Starts recording audio to a temporary file.
  Future<void> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        _currentRecordingPath = '${tempDir.path}/voice_msg_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc, // Standard AAC format
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _currentRecordingPath!,
        );
        _isRecording = true;
      }
    } catch (e) {
      print('Error starting record: $e');
    }
  }

  /// Stops recording and returns the path to the recorded audio file and its duration.
  Future<Map<String, dynamic>?> stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _isRecording = false;

      if (path != null) {
        // Find duration
        await _audioPlayer.setSourceDeviceFile(path);
        final duration = await _audioPlayer.getDuration();
        
        return {
          'path': path,
          'duration': duration?.inMilliseconds ?? 0,
        };
      }
    } catch (e) {
      print('Error stopping record: $e');
    }
    return null;
  }

  /// Cancels the current recording and deletes the temporary file.
  Future<void> cancelRecording() async {
    try {
      await _audioRecorder.stop();
      _isRecording = false;
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _currentRecordingPath = null;
    } catch (e) {
      print('Error cancelling record: $e');
    }
  }

  // --- Playback Helpers ---

  /// Plays audio from a URL.
  Future<void> playAudio(String url) async {
    await _audioPlayer.play(UrlSource(url));
  }

  /// Pauses the currently playing audio.
  Future<void> pauseAudio() async {
    await _audioPlayer.pause();
  }

  /// Stops the currently playing audio.
  Future<void> stopAudio() async {
    await _audioPlayer.stop();
  }

  /// Stream of player states (playing, paused, stopped, completed)
  Stream<PlayerState> get onPlayerStateChanged => _audioPlayer.onPlayerStateChanged;

  /// Stream of playback position
  Stream<Duration> get onPositionChanged => _audioPlayer.onPositionChanged;

  /// Disposes the recorder and player instances.
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
  }
}
