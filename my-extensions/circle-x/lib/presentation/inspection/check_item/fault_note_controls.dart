import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/check_result.dart';

class FaultNoteControls extends StatelessWidget {
  final CheckResult answer;
  final bool isDictating;
  final bool enabled;
  final VoidCallback onDictateNote;
  final VoidCallback? onEditNote;

  const FaultNoteControls({
    super.key,
    required this.answer,
    required this.isDictating,
    required this.enabled,
    required this.onDictateNote,
    required this.onEditNote,
  });

  static const Color recordingRed = Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    final note = answer.note;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FaultNoteMicButton(
          isDictating: isDictating,
          enabled: enabled,
          onPressed: onDictateNote,
        ),
        Expanded(
          child: Text(
            note == null || note.isEmpty
                ? 'Optional description · up to 155 characters'
                : note,
            style: TextStyle(
              color: note == null || note.isEmpty ? textSecondary : textPrimary,
              fontSize: 12,
              fontStyle: note == null || note.isEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
        ),
        if (onEditNote != null)
          IconButton(
            onPressed: enabled ? onEditNote : null,
            tooltip: faultNoteActionLabel(answer),
            icon: const Icon(Icons.edit_note),
            constraints: const BoxConstraints(
              minWidth: minTouchTarget,
              minHeight: minTouchTarget,
            ),
          ),
      ],
    );
  }
}

class FaultNoteMicButton extends StatelessWidget {
  final bool isDictating;
  final bool enabled;
  final VoidCallback onPressed;

  const FaultNoteMicButton({
    super.key,
    required this.isDictating,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const recordingRed = FaultNoteControls.recordingRed;
    return IconButton(
      onPressed: enabled ? onPressed : null,
      icon: Icon(
        isDictating ? Icons.mic : Icons.mic_none,
        color: isDictating ? recordingRed : masterChiefGreen,
        size: 24,
      ),
      style: IconButton.styleFrom(
        backgroundColor:
            isDictating ? recordingRed.withAlpha(38) : Colors.transparent,
        shape: const CircleBorder(),
        minimumSize: const Size(minTouchTarget, minTouchTarget),
      ),
      tooltip: isDictating ? 'Recording — tap to stop' : 'Tap to record',
    );
  }
}

String faultNoteActionLabel(CheckResult answer) =>
    answer.note?.isNotEmpty == true ? 'Edit description' : 'Add description';
