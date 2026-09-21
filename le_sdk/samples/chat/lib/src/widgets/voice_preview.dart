import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';

/// Preview widget shown after recording a voice note, before sending.
/// Allows the user to play back, delete, or send the recording.
class VoicePreview extends StatefulWidget {
  final String audioPath;
  final VoidCallback onSend;
  final VoidCallback onDelete;

  const VoicePreview({
    super.key,
    required this.audioPath,
    required this.onSend,
    required this.onDelete,
  });

  @override
  State<VoicePreview> createState() => _VoicePreviewState();
}

class _VoicePreviewState extends State<VoicePreview> {
  late final AudioPlayer _player;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _completeSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durSub = _player.onDurationChanged.listen((dur) {
      if (dur.inMilliseconds > 0 && mounted) {
        setState(() => _duration = dur);
      }
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
    _loadDuration();
  }

  Future<void> _loadDuration() async {
    if (widget.audioPath.isEmpty) return;
    if (!File(widget.audioPath).existsSync()) return;
    final probe = AudioPlayer();
    try {
      await probe.setSource(DeviceFileSource(widget.audioPath));
      final dur = await probe.getDuration();
      if (dur != null && dur.inMilliseconds > 0 && mounted) {
        setState(() => _duration = dur);
      }
    } catch (e) {
      debugPrint('[VoicePreview] Failed to load duration: $e');
    } finally {
      probe.dispose();
    }
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      if (_position == Duration.zero) {
        await _player.play(DeviceFileSource(widget.audioPath));
      } else {
        await _player.resume();
      }
      setState(() => _isPlaying = true);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.borderActive),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Delete button
          GestureDetector(
            onTap: widget.onDelete,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.delete, size: 18, color: colors.error),
            ),
          ),
          const SizedBox(width: 8),

          // Play/pause button
          GestureDetector(
            onTap: _togglePlayback,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                size: 18,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Progress bar + duration
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: colors.borderActive,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _duration.inMilliseconds > 0
                      ? _formatDuration(_isPlaying ? _position : _duration)
                      : '0:00',
                  style: TextStyle(fontSize: 10, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: widget.onSend,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.send, size: 18, color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
