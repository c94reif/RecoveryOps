import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';

/// Recording indicator shown in the input area while recording a voice note.
class VoiceRecorder extends StatefulWidget {
  final VoidCallback onStop;
  final Duration maxDuration;

  const VoiceRecorder({
    super.key,
    required this.onStop,
    this.maxDuration = const Duration(seconds: 30),
  });

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  late Timer _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
      if (_elapsedSeconds >= widget.maxDuration.inSeconds) {
        widget.onStop();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    final remaining = widget.maxDuration.inSeconds - _elapsedSeconds;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.error),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Recording ${_formatTime(_elapsedSeconds)}',
            style: TextStyle(fontSize: 13, color: colors.textPrimary),
          ),
          const Spacer(),
          Text(
            '${remaining}s left',
            style: TextStyle(fontSize: 11, color: colors.textSecondary),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onStop,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.error,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Icon(Icons.stop, size: 18, color: colors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
