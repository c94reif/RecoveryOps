import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:circle_x/core/platform/cac_camera_geometry.dart';

class CacLivePreview extends StatefulWidget {
  final CameraController controller;
  final Future<void> Function(Offset) onFocus;
  final Widget guide;

  const CacLivePreview({
    super.key,
    required this.controller,
    required this.onFocus,
    required this.guide,
  });

  @override
  State<CacLivePreview> createState() => _CacLivePreviewState();
}

class _CacLivePreviewState extends State<CacLivePreview> {
  Offset? _focusPoint;
  Timer? _focusIndicator;

  @override
  void dispose() {
    _focusIndicator?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => ValueListenableBuilder<CameraValue>(
          valueListenable: widget.controller,
          builder: (context, value, _) {
            final size = CacCameraGeometry.uprightPreview(widget.controller);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final point = Offset(
                  details.localPosition.dx / constraints.maxWidth,
                  details.localPosition.dy / constraints.maxHeight,
                );
                setState(() => _focusPoint = point);
                _focusIndicator?.cancel();
                _focusIndicator = Timer(const Duration(seconds: 1), () {
                  if (mounted) setState(() => _focusPoint = null);
                });
                unawaited(widget.onFocus(point));
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: size.width,
                      height: size.height,
                      child: CameraPreview(widget.controller),
                    ),
                  ),
                  widget.guide,
                  if (_focusPoint case final point?)
                    Positioned(
                      left: point.dx * constraints.maxWidth - 18,
                      top: point.dy * constraints.maxHeight - 18,
                      child: IgnorePointer(
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
}
