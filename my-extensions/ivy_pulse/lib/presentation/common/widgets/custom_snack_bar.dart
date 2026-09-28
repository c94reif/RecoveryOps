import 'package:ivy_pulse/presentation/common/services/snack_bar_service.dart';
export 'package:ivy_pulse/presentation/common/services/snack_bar_service.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';

class CustomSnackBar extends StatefulWidget {
  final Widget child;
  final SnackBarService? service;

  const CustomSnackBar({super.key, required this.child, this.service});

  @override
  State<CustomSnackBar> createState() => CustomSnackBarState();
}

class CustomSnackBarState extends State<CustomSnackBar> {
  late SnackBarService service;
  SnackBarData? current;
  bool isVisible = false;
  Timer? dismissTimer;
  Timer? transitionTimer;

  @override
  void initState() {
    super.initState();
    service = widget.service ?? SnackBarService.instance;
    service.addListener(onServiceUpdate);
    showNext();
  }

  @override
  void didUpdateWidget(covariant CustomSnackBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextService = widget.service ?? SnackBarService.instance;
    if (identical(service, nextService)) return;
    service.removeListener(onServiceUpdate);
    dismissTimer?.cancel();
    transitionTimer?.cancel();
    service = nextService;
    service.addListener(onServiceUpdate);
    showNext();
  }

  void onServiceUpdate() {
    if (current == null && service.hasMessages) {
      showNext();
    }
  }

  void showNext() {
    setState(() {
      current = service.dequeue();
      isVisible = current != null;
    });

    if (current == null || current!.persistent) return;
    dismissTimer = Timer(const Duration(seconds: 3), dismiss);
  }

  void dismiss() {
    if (!isVisible) return;
    dismissTimer?.cancel();
    setState(() {
      isVisible = false;
    });
    transitionTimer = Timer(const Duration(milliseconds: 300), showNext);
  }

  @override
  void dispose() {
    service.removeListener(onServiceUpdate);
    dismissTimer?.cancel();
    transitionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = current;
    final accent = message?.isError == true ? redXRed : serviceableGreen;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          widget.child,
          if (message != null)
            Positioned(
              bottom: 64,
              left: 12,
              right: 12,
              child: SafeArea(
                top: false,
                child: IgnorePointer(
                  ignoring: !isVisible,
                  child: ExcludeSemantics(
                    excluding: !isVisible,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: isVisible ? 1 : 0,
                      child: Semantics(
                        liveRegion: true,
                        child: Material(
                          color: surface,
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: accent),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                            child: Row(
                              children: [
                                Icon(
                                  message.isError
                                      ? Icons.error_outline
                                      : Icons.check_circle_outline,
                                  color: accent,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: constraints.maxHeight * 0.5,
                                    ),
                                    child: SingleChildScrollView(
                                      child: Text(
                                        message.message,
                                        style: const TextStyle(
                                          color: textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: dismiss,
                                  tooltip: 'Dismiss notification',
                                  constraints: const BoxConstraints(
                                    minWidth: minTouchTarget,
                                    minHeight: minTouchTarget,
                                  ),
                                  icon: const Icon(Icons.close, size: 20),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
