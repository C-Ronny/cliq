import 'dart:async';
// import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:audio_waveforms/audio_waveforms.dart';

class AudioUtils {
  static final AudioUtils _instance = AudioUtils._internal();

  factory AudioUtils() => _instance;

  AudioUtils._internal();

  AudioRecorder? _audioRecorder;
  just_audio.AudioPlayer? _audioPlayer;
  String? currentlyPlayingId;
  final Map<String, StreamSubscription<just_audio.PlayerState>> _audioListeners = {};
  bool _isRecording = false;
  String? _recordingPath;

  Future<void> initialize() async {
    _audioRecorder ??= AudioRecorder();
    _audioPlayer ??= just_audio.AudioPlayer();
  }

  void dispose() {
    for (final subscription in _audioListeners.values) {
      subscription.cancel();
    }
    _audioListeners.clear();
    _audioPlayer?.dispose();
    _audioRecorder?.dispose();
    _audioRecorder = null;
    _audioPlayer = null;
    currentlyPlayingId = null;
  }

  bool get isRecording => _isRecording;

  Future<String?> startRecording() async {
    if (_isRecording) return null;

    await initialize();

    if (await _audioRecorder!.hasPermission()) {
      final directory = await getTemporaryDirectory();
      _recordingPath =
          '${directory.path}/audio_message_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
        ),
        path: _recordingPath!,
      );

      _isRecording = true;
      return _recordingPath;
    }
    return null;
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    final path = await _audioRecorder!.stop();
    _isRecording = false;
    return path;
  }

  Future<void> playAudio(String messageId, String audioUrl) async {
    await initialize();

    if (currentlyPlayingId == messageId) {
      await _audioPlayer!.pause();
      currentlyPlayingId = null;
      return;
    }

    if (currentlyPlayingId != null) {
      await _audioPlayer!.stop();
      await _audioListeners[currentlyPlayingId]?.cancel();
      _audioListeners.remove(currentlyPlayingId);
      currentlyPlayingId = null;
    }

    try {
      currentlyPlayingId = messageId;
      await _audioPlayer!.setUrl(audioUrl);
      await _audioPlayer!.play();

      final subscription = _audioPlayer!.playerStateStream.listen((state) {
        if (state.processingState == just_audio.ProcessingState.completed) {
          if (currentlyPlayingId == messageId) {
            currentlyPlayingId = null;
            _audioListeners[messageId]?.cancel();
            _audioListeners.remove(messageId);
          }
        }
      });

      _audioListeners[messageId] = subscription;
    } catch (e) {
      print('Error playing audio: $e');
      currentlyPlayingId = null;
    }
  }

  Stream<Duration>? get positionStream => _audioPlayer?.positionStream;

  Duration? get duration => _audioPlayer?.duration;

  Future<void> pauseAudio() async {
    await _audioPlayer?.pause();
  }

  Future<PlayerController> createPlayerController(String path) async {
    final controller = PlayerController();
    await controller.preparePlayer(path: path);
    return controller;
  }
}