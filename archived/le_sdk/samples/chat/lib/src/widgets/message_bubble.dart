import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';

import '../models/message.dart';
import 'voice_note_player.dart';

/// A single chat message bubble (text or voice note).
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isOutgoing;
  final bool showSenderLabel;
  final String? senderCallsign;
  final VoidCallback? onRetry;
  final void Function(String path)? onPlayVoice;
  final String? currentlyPlayingPath;
  final Stream<Duration>? positionStream;
  final Stream<Duration>? durationStream;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isOutgoing,
    this.showSenderLabel = false,
    this.senderCallsign,
    this.onRetry,
    this.onPlayVoice,
    this.currentlyPlayingPath,
    this.positionStream,
    this.durationStream,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    final time = DateTime.fromMillisecondsSinceEpoch(message.timestamp);
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment:
            isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSenderLabel && !isOutgoing && senderCallsign != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                senderCallsign!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Container(
              decoration: BoxDecoration(
                color: isOutgoing
                    ? colors.accent
                    : colors.surface,
                border: isOutgoing
                    ? null
                    : Border.all(color: colors.borderActive),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isOutgoing ? 12 : 4),
                  bottomRight: Radius.circular(isOutgoing ? 4 : 12),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: message.type == MessageType.voice
                  ? VoiceNotePlayer(
                      audioPath: message.audioPath ?? '',
                      isOutgoing: isOutgoing,
                      isPlaying: currentlyPlayingPath == message.audioPath,
                      onTap: () {
                        if (message.audioPath != null) {
                          onPlayVoice?.call(message.audioPath!);
                        }
                      },
                      positionStream: positionStream,
                      durationStream: durationStream,
                    )
                  : Text(
                      message.body ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: isOutgoing
                            ? colors.onAccent
                            : colors.textPrimary,
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 9,
                    color: colors.textMuted,
                  ),
                ),
                if (isOutgoing &&
                    message.status == MessageStatus.failed) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onRetry,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Icon(
                          Icons.error_outline,
                          size: 16,
                          color: colors.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
