import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';

/// Self-contained inline voice note player.
///
/// Each instance owns its own [AudioPlayer] so multiple voice notes
/// in the same conversation play independently without interference.
class VoiceNotePlayer extends StatefulWidget {
  final String audioPath;
  final bool isOutgoing;

  const VoiceNotePlayer({
    super.key,
    required this.audioPath,
    required this.isOutgoing,
  });

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  late final AudioPlayer _player;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _completeSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _durationLoaded = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durSub = _player.onDurationChanged.listen((dur) {
      if (dur.inMilliseconds > 0 && mounted) {
        setState(() {
          _duration = dur;
          _durationLoaded = true;
        });
      }
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isPaused = false;
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
        setState(() {
          _duration = dur;
          _durationLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('[VoiceNotePlayer] Failed to load duration: $e');
    } finally {
      probe.dispose();
    }
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      setState(() {
        _isPlaying = false;
        _isPaused = true;
      });
      await _player.pause();
    } else if (_isPaused) {
      setState(() {
        _isPlaying = true;
        _isPaused = false;
      });
      await _player.resume();
    } else {
      setState(() {
        _isPlaying = true;
        _isPaused = false;
        _position = Duration.zero;
      });
      await _player.play(DeviceFileSource(widget.audioPath));
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
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    final isActive = _isPlaying || _isPaused;
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final displayDuration = isActive ? _position : _duration;

    return GestureDetector(
      onTap: _togglePlayback,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: widget.isOutgoing
                  ? colors.background.withValues(alpha: 0.2)
                  : colors.accent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              size: 18,
              color: widget.isOutgoing
                  ? colors.background
                  : colors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: widget.isOutgoing
                        ? colors.background.withValues(alpha: 0.2)
                        : colors.borderActive,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.isOutgoing
                          ? colors.background
                          : colors.accent,
                    ),
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _durationLoaded
                      ? _formatDuration(displayDuration)
                      : '0:00',
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isOutgoing
                        ? colors.background.withValues(alpha: 0.7)
                        : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
