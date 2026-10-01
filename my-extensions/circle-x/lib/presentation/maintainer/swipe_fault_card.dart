import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/pmcs_fault.dart';
import 'package:circle_x/presentation/common/widgets/fault_summary_line.dart';

class SwipeFaultCard extends StatefulWidget {
  final PmcsFault fault;
  final bool? decision;
  final ValueChanged<bool> onDecision;
  final bool enabled;
  final bool hasNext;
  final ValueChanged<bool>? onAnimatingChanged;

  const SwipeFaultCard(
      {super.key,
      required this.fault,
      required this.decision,
      this.enabled = true,
      this.hasNext = false,
      this.onAnimatingChanged,
      required this.onDecision});

  @override
  State<SwipeFaultCard> createState() => _SwipeFaultCardState();
}

class _SwipeFaultCardState extends State<SwipeFaultCard>
    with TickerProviderStateMixin {
  late final motion = AnimationController.unbounded(vsync: this);
  late final entrance = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280));
  bool started = false;
  bool committing = false;
  bool get reducedMotion => MediaQuery.disableAnimationsOf(context);
  bool get interactive => widget.enabled && !committing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion) {
      entrance.value = 1;
    } else if (!started) {
      entrance.forward();
    }
    started = true;
  }

  @override
  void didUpdateWidget(SwipeFaultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      motion.stop();
      motion.value = 0;
      committing = false;
    }
  }

  Future<void> settle() async {
    if (reducedMotion) {
      motion.value = 0;
      return;
    }
    try {
      await motion
          .animateTo(0,
              duration: const Duration(milliseconds: 340),
              curve: Curves.easeOutBack)
          .orCancel;
    } on TickerCanceled {
      // A new drag, navigation, or dictation supersedes this animation.
    }
  }

  Future<void> commit(bool verified, double width) async {
    if (!interactive) return;
    FocusScope.of(context).unfocus();
    setState(() => committing = true);
    widget.onAnimatingChanged?.call(true);
    try {
      if (!reducedMotion) {
        await motion
            .animateTo((verified ? 1 : -1) * (width + 100),
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInCubic)
            .orCancel;
      }
      if (!mounted || !widget.enabled) return;
      motion.value = 0;
      if (!reducedMotion) entrance.forward(from: 0);
      setState(() => committing = false);
      widget.onAnimatingChanged?.call(false);
      widget.onDecision(verified);
    } on TickerCanceled {
      // Never apply an outgoing card's decision to a different fault.
    }
  }

  @override
  void dispose() {
    motion.dispose();
    entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final threshold = (width * .25).clamp(70.0, 120.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Swipe left: Not verified  ·  Swipe right: Verified',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              ClipRect(
                child: GestureDetector(
                  key: const ValueKey('fault-swipe-area'),
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart:
                      interactive ? (_) => motion.stop() : null,
                  onHorizontalDragUpdate: interactive
                      ? (details) => motion.value =
                          (motion.value + details.delta.dx).clamp(-width, width)
                      : null,
                  onHorizontalDragCancel: interactive ? settle : null,
                  onHorizontalDragEnd: interactive
                      ? (details) {
                          final distance = motion.value;
                          final velocity = details.primaryVelocity ?? 0;
                          final flick = velocity.abs() > 700 &&
                              distance.abs() > 28 &&
                              velocity.sign == distance.sign;
                          if (distance.abs() >= threshold || flick) {
                            commit(distance > 0, width);
                          } else {
                            settle();
                          }
                        }
                      : null,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([motion, entrance]),
                    builder: (context, _) {
                      final drag = motion.value;
                      final progress = (drag.abs() / threshold).clamp(0.0, 1.0);
                      final choice =
                          drag.abs() > 12 ? drag > 0 : widget.decision;
                      final color = choice == null
                          ? border
                          : choice
                              ? serviceableGreen
                              : circleXAmber;
                      final arrival =
                          Curves.easeOutCubic.transform(entrance.value);
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(6, 8, 6, 14),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (widget.hasNext)
                              Positioned.fill(
                                child: Transform.translate(
                                  offset: Offset(0, 10 - progress * 5),
                                  child: Transform.scale(
                                    scale: .95 + progress * .025,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                          color: surfaceLight,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(color: border)),
                                    ),
                                  ),
                                ),
                              ),
                            Opacity(
                              opacity: reducedMotion
                                  ? 1
                                  : arrival *
                                      (1 -
                                          (drag.abs() / (width + 100))
                                                  .clamp(0.0, 1.0) *
                                              .65),
                              child: Transform.translate(
                                key: const ValueKey('fault-card-motion'),
                                offset: reducedMotion
                                    ? Offset.zero
                                    : Offset(drag, (1 - arrival) * 22),
                                child: Transform.rotate(
                                  angle: reducedMotion
                                      ? 0
                                      : (drag / width).clamp(-1.0, 1.0) * .18,
                                  child: Transform.scale(
                                    scale:
                                        reducedMotion ? 1 : .96 + arrival * .04,
                                    child: _FaultFace(
                                        fault: widget.fault,
                                        choice: choice,
                                        color: color,
                                        progress: progress,
                                        stamp: drag > 0),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                decisionButton(false, width),
                const SizedBox(width: 8),
                decisionButton(true, width),
              ]),
            ],
          );
        },
      );

  Widget decisionButton(bool verified, double width) => Expanded(
        child: OutlinedButton.icon(
          onPressed: interactive ? () => commit(verified, width) : null,
          icon: Icon(verified ? Icons.check : Icons.close,
              color: verified ? serviceableGreen : circleXAmber),
          label: Text(verified ? 'Verified' : 'Not verified',
              textAlign: TextAlign.center),
          style: OutlinedButton.styleFrom(
            foregroundColor: verified ? serviceableGreen : circleXAmber,
            backgroundColor: verified ? serviceableGlow : circleXGlow,
            side: BorderSide(color: verified ? serviceableGreen : circleXAmber),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            minimumSize: const Size(0, minTouchTarget),
          ),
        ),
      );
}

class _FaultFace extends StatelessWidget {
  final PmcsFault fault;
  final bool? choice;
  final Color color;
  final double progress;
  final bool stamp;
  const _FaultFace(
      {required this.fault,
      required this.choice,
      required this.color,
      required this.progress,
      required this.stamp});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color.lerp(surface, color, progress * .10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .2 + progress * .15),
                blurRadius: 12,
                offset: const Offset(0, 5))
          ],
        ),
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fault.category,
                style: const TextStyle(color: textSecondary, fontSize: 12)),
            FaultSummaryLine(fault: fault, showNote: true),
            const SizedBox(height: 12),
            Text(
                choice == null
                    ? 'Choose a review decision'
                    : choice!
                        ? 'Verified'
                        : 'Not verified',
                style: TextStyle(
                    color: choice == null ? textSecondary : color,
                    fontWeight: FontWeight.w700)),
          ]),
          if (progress > 0)
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: Align(
                    alignment: stamp ? Alignment.topLeft : Alignment.topRight,
                    child: Opacity(
                      opacity: progress,
                      child: Transform.rotate(
                        angle: stamp ? -.10 : .10,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: surface.withValues(alpha: .95),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color:
                                      stamp ? serviceableGreen : circleXAmber,
                                  width: 3),
                            ),
                            child: Text(stamp ? 'VERIFIED' : 'NOT VERIFIED',
                                style: TextStyle(
                                    color:
                                        stamp ? serviceableGreen : circleXAmber,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );
}
