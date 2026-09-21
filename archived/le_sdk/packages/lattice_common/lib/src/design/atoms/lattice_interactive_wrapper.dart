import 'package:flutter/material.dart';

import '../tokens/lattice_spacing.dart';

/// The resolved interactive state of a [LatticeInteractiveWrapper].
///
/// Priority order (highest wins): disabled > pressed > selected > focused >
/// hovered > idle. The wrapper resolves exactly one state at a time.
enum LatticeInteractiveState {
  /// No interaction occurring.
  idle,

  /// Pointer is hovering over the widget (mouse/trackpad only).
  hovered,

  /// Widget has keyboard focus.
  focused,

  /// Widget is being pressed (pointer down, not yet released).
  pressed,

  /// Widget is marked as selected by its parent.
  selected,

  /// Widget is disabled and ignores all input.
  disabled,
}

/// A unified interactive feedback wrapper for any child widget.
///
/// Tracks hover, press, focus, selected, and disabled states internally and
/// paints a tinted overlay on top of the child to communicate state. Uses
/// [GestureDetector], [MouseRegion], and [Focus] — no Material ripple or
/// [InkWell].
///
/// Two API styles:
/// - **Simple:** pass a [child] widget.
/// - **Builder:** pass a [builder] that receives the resolved
///   [LatticeInteractiveState] so the child can adapt its own rendering.
///
/// ```dart
/// LatticeInteractiveWrapper(
///   onTap: () => doSomething(),
///   borderRadius: BorderRadius.circular(8),
///   child: Text('Tap me'),
/// )
/// ```
class LatticeInteractiveWrapper extends StatefulWidget {
  /// Creates an interactive wrapper.
  ///
  /// Exactly one of [child] or [builder] must be non-null.
  const LatticeInteractiveWrapper({
    super.key,
    required this.onTap,
    this.child,
    this.builder,
    this.onLongPress,
    this.enabled = true,
    this.isSelected = false,
    this.borderRadius,
    this.semanticLabel,
  }) : assert(
          child != null || builder != null,
          'Either child or builder must be provided',
        );

  /// Tap callback. When null the wrapper still renders but does not respond to
  /// taps (useful when only [onLongPress] is needed).
  final VoidCallback? onTap;

  /// Static child widget — ignored if [builder] is provided.
  final Widget? child;

  /// Builder that receives the current resolved state, allowing the child to
  /// adapt its own rendering. Takes priority over [child].
  final Widget Function(BuildContext context, LatticeInteractiveState state)?
      builder;

  /// Long-press callback.
  final VoidCallback? onLongPress;

  /// Whether the wrapper responds to input. When false, opacity drops to 0.38
  /// and all gestures are ignored.
  final bool enabled;

  /// External selected state set by the parent.
  final bool isSelected;

  /// Border radius for clipping the overlay and focus ring.
  final BorderRadius? borderRadius;

  /// Accessibility label forwarded to [Semantics].
  final String? semanticLabel;

  @override
  State<LatticeInteractiveWrapper> createState() =>
      _LatticeInteractiveWrapperState();
}

class _LatticeInteractiveWrapperState extends State<LatticeInteractiveWrapper> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;

  /// Opacity applied to the overlay for hover feedback.
  static const double _hoverOverlayOpacity = 0.08;

  /// Opacity applied to the overlay for press feedback.
  static const double _pressOverlayOpacity = 0.12;

  /// Color used for the focus ring.
  static const Color _focusRingColor = Color(0xFF5569ED);

  /// Width of the focus ring border.
  static const double _focusRingWidth = 2.0;

  /// Opacity multiplier applied when the widget is disabled.
  static const double _disabledOpacity = 0.38;

  /// Resolve the current state using the documented priority order:
  /// disabled > pressed > selected > focused > hovered > idle.
  LatticeInteractiveState get _resolvedState {
    if (!widget.enabled) return LatticeInteractiveState.disabled;
    if (_isPressed) return LatticeInteractiveState.pressed;
    if (widget.isSelected) return LatticeInteractiveState.selected;
    if (_isFocused) return LatticeInteractiveState.focused;
    if (_isHovered) return LatticeInteractiveState.hovered;
    return LatticeInteractiveState.idle;
  }

  /// Whether the current platform input is touch-only (no mouse connected).
  bool _isTouchOnly(BuildContext context) {
    // On devices with no mouse attached the hover state is meaningless.
    // `WidgetsBinding.platformDispatcher.views` always has at least one view;
    // however the simplest heuristic is to suppress hover on devices where the
    // primary input kind is touch. We check this via the platform brightness
    // fallback: if a mouse is attached, `_isHovered` will still be set by
    // `MouseRegion`, so we only use this to gate the overlay.
    final data = MediaQuery.maybeOf(context);
    if (data == null) return false;
    // If no mouse/trackpad is connected the system typically reports 0
    // pointer-type devices that support hover.
    return data.navigationMode == NavigationMode.directional;
  }

  BorderRadius get _effectiveRadius =>
      widget.borderRadius ??
      BorderRadius.circular(LatticeSpacing.borderRadius);

  // -- Gesture callbacks --

  void _onTapDown(TapDownDetails _) {
    if (!widget.enabled) return;
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    if (!widget.enabled) return;
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    if (!widget.enabled) return;
    setState(() => _isPressed = false);
  }

  void _onHoverEnter(PointerEvent _) {
    if (!widget.enabled) return;
    setState(() => _isHovered = true);
  }

  void _onHoverExit(PointerEvent _) {
    setState(() => _isHovered = false);
  }

  void _onFocusChange(bool focused) {
    setState(() => _isFocused = focused);
  }

  @override
  Widget build(BuildContext context) {
    final state = _resolvedState;
    final bool touchOnly = _isTouchOnly(context);

    // Build the child content.
    final Widget content = widget.builder != null
        ? widget.builder!(context, state)
        : widget.child!;

    // Determine overlay color.
    Color? overlayColor;
    if (widget.enabled) {
      if (_isPressed) {
        overlayColor = Colors.white.withValues(alpha: _pressOverlayOpacity);
      } else if (_isHovered && !touchOnly) {
        overlayColor = Colors.white.withValues(alpha: _hoverOverlayOpacity);
      }
    }

    // Focus ring decoration.
    final bool showFocusRing = _isFocused && widget.enabled;

    Widget result = ClipRRect(
      borderRadius: _effectiveRadius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          content,
          // Overlay tint layer.
          if (overlayColor != null)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: overlayColor,
                    borderRadius: _effectiveRadius,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // Focus ring wraps the clipped stack.
    if (showFocusRing) {
      result = Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: _focusRingColor,
            width: _focusRingWidth,
          ),
          borderRadius: _effectiveRadius,
        ),
        child: result,
      );
    }

    // Disabled opacity.
    if (!widget.enabled) {
      result = Opacity(
        opacity: _disabledOpacity,
        child: result,
      );
    }

    // Wrap with gesture handling, mouse region, and focus.
    result = Focus(
      onFocusChange: _onFocusChange,
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: _onHoverEnter,
        onExit: _onHoverExit,
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          onLongPress: widget.enabled ? widget.onLongPress : null,
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          behavior: HitTestBehavior.opaque,
          child: result,
        ),
      ),
    );

    // Semantics wrapper.
    if (widget.semanticLabel != null) {
      result = Semantics(
        label: widget.semanticLabel,
        button: true,
        enabled: widget.enabled,
        selected: widget.isSelected,
        child: result,
      );
    }

    return result;
  }
}
