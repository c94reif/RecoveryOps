import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:circle_x/domain/entities/queued_submission.dart';
import 'package:circle_x/presentation/common/formatters/report_time.dart';
import 'package:circle_x/presentation/common/widgets/section_label.dart';

class ReportQueueBanner extends StatelessWidget {
  final ValueListenable<int> queuedCount;

  const ReportQueueBanner({
    super.key,
    required this.queuedCount,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: queuedCount,
      builder: (_, count, __) {
        if (count == 0) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: circleXGlow,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.cloud_off, size: 16, color: circleXAmber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$count submission${count == 1 ? '' : 's'} queued — '
                  'will send on reconnect',
                  style: const TextStyle(color: circleXAmber, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class QueuedReportCard extends StatelessWidget {
  final QueuedSubmission submission;

  const QueuedReportCard({
    super.key,
    required this.submission,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: circleXAmber, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: circleXAmber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    submission.summary,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  formatRelativeAge(submission.createdAt),
                  style: const TextStyle(color: textSecondary, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${submission.faultSummary} · waiting on '
              '${submission.transport.name}',
              style: const TextStyle(color: textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportBumperHeader extends StatelessWidget {
  final String bumperNumber;
  final int count;

  const ReportBumperHeader({
    super.key,
    required this.bumperNumber,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SectionLabel(text: bumperNumber),
          Text(
            count == 1 ? '1 PMCS' : '$count PMCS',
            style: const TextStyle(color: textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class ReportEmptyLine extends StatelessWidget {
  final String message;

  const ReportEmptyLine({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Text(
        message,
        style: const TextStyle(color: textSecondary, fontSize: 12),
      ),
    );
  }
}
