import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/presentation/maintainer/review_completion_mark.dart';

class ReviewCompletionDialog extends StatefulWidget {
  final String vehicle;
  final int verifiedCount;
  final int total;

  const ReviewCompletionDialog({
    super.key,
    required this.vehicle,
    required this.verifiedCount,
    required this.total,
  });

  @override
  State<ReviewCompletionDialog> createState() => _ReviewCompletionDialogState();
}

class _ReviewCompletionDialogState extends State<ReviewCompletionDialog>
    with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      animation.value = 1;
    } else if (!started) {
      animation.forward();
    }
    started = true;
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allVerified = widget.verifiedCount == widget.total;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: serviceableGreen)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF20382B), surface, bgDark],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedBuilder(
                animation: animation,
                builder: (context, _) =>
                    ReviewCompletionMark(progress: animation.value),
              ),
              const Text('REVIEW COMPLETE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: serviceableGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2)),
              const SizedBox(height: 10),
              Semantics(
                namesRoute: true,
                header: true,
                child: Text(
                    allVerified ? 'All faults verified' : 'All faults reviewed',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.1)),
              ),
              const SizedBox(height: 12),
              Text(widget.vehicle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              Text(
                  allVerified
                      ? '${widget.total} of ${widget.total} verified'
                      : '${widget.verifiedCount} verified · '
                          '${widget.total - widget.verifiedCount} not verified',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: textPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                  'Your review is still a draft.\nSign with your CAC to submit.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary, height: 1.5)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: serviceableGreen,
                      foregroundColor: bgDark,
                      minimumSize: const Size(0, minTouchTarget)),
                  icon: const Icon(Icons.badge_outlined),
                  label:
                      const Text('Sign & submit', textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                    foregroundColor: textSecondary,
                    minimumSize: const Size(0, minTouchTarget)),
                child: const Text('Keep editing'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
