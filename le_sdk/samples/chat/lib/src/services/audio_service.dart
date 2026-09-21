import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Why recording is (un)available, so callers can show a specific message.
enum MicAvailability {
  /// A capture source is present and recording can proceed.
  available,

  /// The audio tooling enumerated fine but found no capture device — the
  /// box/device simply has no microphone connected.
  noMicrophone,

  /// The device-enumeration call itself failed. On Linux this is almost
  /// always the audio tooling being absent (e.g. `parecord`/`pactl` from
  /// pulseaudio-utils not installed), but any enumeration error lands here.
  toolingUnavailable,
}

/// Service for recording voice notes.
///
/// Playback is handled per-widget by [VoiceNotePlayer] which owns its
/// own [AudioPlayer] instance, so multiple memos play independently.
class AudioService {
  static const Duration maxRecordDuration = Duration(seconds: 30);

  final AudioRecorder _recorder = AudioRecorder();
  Timer? _autoStopTimer;

  /// Called when the max-duration timer fires and recording is auto-stopped.
  /// The argument is the final file path (same value [stopRecording] returns).
  void Function(String path)? onAutoStop;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// True only on mobile, which has a per-app microphone permission model.
  /// Desktop (Linux/macOS/Windows) governs mic access through the audio server
  /// (PipeWire/PulseAudio), and `permission_handler` has no desktop
  /// implementation — calling it there returns a non-granted status and would
  /// silently block recording. Gate the permission calls to mobile only.
  bool get _needsMicPermission =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<bool> requestPermission() async {
    if (!_needsMicPermission) return true;
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> hasPermission() async {
    if (!_needsMicPermission) return true;
    return await Permission.microphone.isGranted;
  }

  /// Whether a usable microphone is available, distinguishing "no mic" from
  /// "audio tooling missing" so callers can show a specific message.
  ///
  /// Uses `record`'s cross-platform [AudioRecorder.listInputDevices], which
  /// enumerates capture devices: `AudioDeviceInfo` inputs on Android, and
  /// `pactl list sources` on Linux. An empty list means no microphone; a thrown
  /// error means the enumeration mechanism itself failed (on Linux, typically
  /// pulseaudio-utils not installed).
  Future<MicAvailability> checkMicAvailability() async {
    try {
      final devices = await _recorder.listInputDevices();
      return devices.isEmpty
          ? MicAvailability.noMicrophone
          : MicAvailability.available;
    } catch (e) {
      debugPrint('[AudioService] input-device enumeration failed: $e');
      return MicAvailability.toolingUnavailable;
    }
  }

  /// Starts recording and returns the target file path, or `null` if recording
  /// could not start. Returns null (rather than throwing) in every degradation
  /// case so the caller simply doesn't enter the recording state:
  ///   * Permission not granted (mobile).
  ///   * No microphone / audio tooling available ([checkMicAvailability]) —
  ///     covers a device with no mic, and Linux boxes missing pulseaudio-utils.
  ///   * On Linux, `record` shells out to `parecord`/`ffmpeg`; if those are
  ///     absent `_recorder.start` throws — caught below as a final backstop.
  Future<String?> startRecording(String messageId) async {
    if (_isRecording) return null;
    if (!await hasPermission()) return null;
    if (await checkMicAvailability() != MicAvailability.available) {
      debugPrint('[AudioService] no microphone available — recording skipped');
      return null;
    }

    final dir = await getApplicationDocumentsDirectory();
    final filePath = p.join(dir.path, 'voice_$messageId.aac');

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 22050,
        ),
        path: filePath,
      );
    } catch (e) {
      debugPrint('[AudioService] recording unavailable: $e');
      _isRecording = false;
      return null;
    }
    _isRecording = true;

    _autoStopTimer = Timer(maxRecordDuration, () async {
      final path = await stopRecording();
      if (path != null) onAutoStop?.call(path);
    });

    return filePath;
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    _autoStopTimer?.cancel();
    _isRecording = false;
    return await _recorder.stop();
  }

  void dispose() {
    _autoStopTimer?.cancel();
    _recorder.dispose();
  }
}
