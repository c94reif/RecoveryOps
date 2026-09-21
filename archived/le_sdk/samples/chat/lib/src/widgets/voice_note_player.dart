import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';

/// Inline voice note player: play/pause button + progress bar + duration.
class VoiceNotePlayer extends StatefulWidget {
  final String audioPath;
  final bool isOutgoing;
  final bool isPlaying;
  final VoidCallback onTap;
  final Stream<Duration>? positionStream;
  final Stream<Duration>? durationStream;

  const VoiceNotePlayer({
    super.key,
    required this.audioPath,
    required this.isOutgoing,
    required this.isPlaying,
    required this.onTap,
    this.positionStream,
    this.durationStream,
  });

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  Duration _position = Duration.zero;
  Duration _duration = const Duration(seconds: 1);
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(VoiceNotePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying && !widget.isPlaying) {
      setState(() => _position = Duration.zero);
    }
    if (oldWidget.positionStream != widget.positionStream) {
      _posSub?.cancel();
      _durSub?.cancel();
      _subscribe();
    }
  }

  void _subscribe() {
    _posSub = widget.positionStream?.listen((pos) {
      if (widget.isPlaying && mounted) setState(() => _position = pos);
    });
    _durSub = widget.durationStream?.listen((dur) {
      if (widget.isPlaying && dur.inMilliseconds > 0 && mounted) {
        setState(() => _duration = dur);
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
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
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: widget.onTap,
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
              widget.isPlaying ? Icons.pause : Icons.play_arrow,
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
                  _formatDuration(widget.isPlaying ? _position : _duration),
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
