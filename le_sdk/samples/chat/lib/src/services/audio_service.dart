import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Service for recording and playing back voice notes.
class AudioService {
  static const Duration maxRecordDuration = Duration(seconds: 30);

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  Timer? _autoStopTimer;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  String? _currentlyPlaying;
  String? get currentlyPlaying => _currentlyPlaying;

  Stream<Duration> get positionStream => _player.onPositionChanged;
  Stream<Duration> get durationStream => _player.onDurationChanged;
  Stream<void> get onPlayerComplete => _player.onPlayerComplete;

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> hasPermission() async {
    return await Permission.microphone.isGranted;
  }

  Future<String?> startRecording(String messageId) async {
    if (_isRecording) return null;
    if (!await hasPermission()) return null;

    final dir = await getApplicationDocumentsDirectory();
    final filePath = p.join(dir.path, 'voice_$messageId.aac');

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 22050,
      ),
      path: filePath,
    );
    _isRecording = true;

    _autoStopTimer = Timer(maxRecordDuration, () => stopRecording());

    return filePath;
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    _autoStopTimer?.cancel();
    _isRecording = false;
    return await _recorder.stop();
  }

  Future<void> play(String filePath) async {
    if (_currentlyPlaying == filePath) {
      final state = _player.state;
      if (state == PlayerState.playing) {
        await _player.pause();
        return;
      } else if (state == PlayerState.paused) {
        await _player.resume();
        return;
      }
    }

    await _player.stop();
    _currentlyPlaying = filePath;
    await _player.play(DeviceFileSource(filePath));

    _player.onPlayerComplete.first.then((_) {
      if (_currentlyPlaying == filePath) _currentlyPlaying = null;
    });
  }

  Future<void> stopPlayback() async {
    _currentlyPlaying = null;
    await _player.stop();
  }

  Future<Duration?> getAudioDuration(String filePath) async {
    if (!File(filePath).existsSync()) return null;
    final player = AudioPlayer();
    await player.setSource(DeviceFileSource(filePath));
    final duration = await player.getDuration();
    player.dispose();
    return duration;
  }

  void dispose() {
    _autoStopTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
  }
}
