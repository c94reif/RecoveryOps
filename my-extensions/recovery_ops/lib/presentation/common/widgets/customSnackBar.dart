import 'package:flutter/material.dart';

class SnackBarData {
  final String message;
  final bool isError;
  final bool persistent;

  SnackBarData({required this.message, this.isError = false, this.persistent = false});
}

class SnackBarService extends ChangeNotifier {
  static final SnackBarService instance = SnackBarService._();

  SnackBarService._();

  final List<SnackBarData> queue = [];

  void enqueue(String message, {bool isError = false, bool persistent = false}) {
    queue.add(SnackBarData(message: message, isError: isError, persistent: persistent));
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

  @override
  void initState() {
    super.initState();
    service.addListener(onServiceUpdate);
  }

  void onServiceUpdate() {
    if (!isVisible && service.hasMessages) {
      showNext();
    }
  }

  void showNext() {
    if (!service.hasMessages) {
      setState(() {
        isVisible = false;
        current = null;
      });
      return;
    }

    setState(() {
      current = service.dequeue();
      isVisible = true;
    });

    if (current!.persistent) return;

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          isVisible = false;
        });

        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) showNext();
        });
      }
    });
  }

  void dismiss() {
    setState(() {
      isVisible = false;
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) showNext();
    });
  }

  @override
  void dispose() {
    service.removeListener(onServiceUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (current != null)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            bottom: isVisible ? 50 : -100,
            left: 20,
            right: 20,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: current!.isError
                    ? const Color(0x33B71C1C)
                    : const Color(0x264A7820),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: current!.isError
                      ? const Color(0xFFB71C1C)
                      : const Color(0xFF4A7820),
                  width: 1,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      current!.isError
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      color: current!.isError
                          ? const Color(0xFFB71C1C)
                          : const Color(0xFF4A7820),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        current!.message,
                        style: TextStyle(
                          color: current!.isError
                              ? const Color(0xFFB71C1C)
                              : const Color(0xFF4A7820),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (current!.persistent) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: dismiss,
                        child: Icon(
                          Icons.close,
                          color: current!.isError
                              ? const Color(0xFFB71C1C)
                              : const Color(0xFF4A7820),
                          size: 20,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
