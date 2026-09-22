import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';

class SnackBarData {
  final String message;
  final bool isError;
  final bool persistent;

  SnackBarData(
      {required this.message, this.isError = false, this.persistent = false});
}

class SnackBarService extends ChangeNotifier {
  static final SnackBarService instance = SnackBarService._();

  SnackBarService._();

  final List<SnackBarData> queue = [];

  void enqueue(String message,
      {bool isError = false, bool persistent = false}) {
    queue.add(SnackBarData(
        message: message, isError: isError, persistent: persistent));
    notifyListeners();
  }

  SnackBarData? dequeue() {
    if (queue.isEmpty) return null;
    return queue.removeAt(0);
  }

  bool get hasMessages => queue.isNotEmpty;
}

class CustomSnackBar extends StatefulWidget {
  final Widget child;

  const CustomSnackBar({super.key, required this.child});

  @override
  State<CustomSnackBar> createState() => CustomSnackBarState();
}

class CustomSnackBarState extends State<CustomSnackBar> {
  final SnackBarService service = SnackBarService.instance;
  SnackBarData? current;
  bool isVisible = false;
  Timer? dismissTimer;
  Timer? transitionTimer;

  @override
  void initState() {
    super.initState();
    service.addListener(onServiceUpdate);
    showNext();
  }

  void onServiceUpdate() {
    // Keep the current message until its exit animation finishes. An arrival
    // during that animation must not be consumed by the previous timer.
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
