import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';

import '../models/peer.dart';

/// A contact list tile showing avatar, callsign, last message, and unread badge.
class ContactTile extends StatelessWidget {
  final Peer peer;
  final String? lastMessagePreview;
  final String? lastMessageTime;
  final int unreadCount;
  final VoidCallback onTap;

  const ContactTile({
    super.key,
    required this.peer,
    this.lastMessagePreview,
    this.lastMessageTime,
    this.unreadCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    final firstLetter = peer.callsign.isNotEmpty
        ? peer.callsign[0].toUpperCase()
        : '?';
    final isOnline = peer.isOnline;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colors.border, width: 1),
          ),
        ),
        child: Opacity(
          opacity: isOnline ? 1.0 : 0.5,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline
                      ? colors.success.withValues(alpha: 0.15)
                      : colors.surfaceElevated,
                  border: Border.all(
                    color: isOnline
                        ? colors.success
                        : colors.textMuted,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    firstLetter,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isOnline ? colors.success : colors.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      peer.callsign,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isOnline ? colors.textPrimary : colors.textSecondary,
                      ),
                    ),
                    if (lastMessagePreview != null &&
                        lastMessagePreview!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        lastMessagePreview!,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (lastMessageTime != null)
                    Text(
                      lastMessageTime!,
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.textMuted,
                      ),
                    ),
                  if (unreadCount > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
