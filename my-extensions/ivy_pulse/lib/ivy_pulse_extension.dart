import 'dart:async';

import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';
import 'package:ivy_pulse/core/constants/app_constants.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/services/queue_prompt_strategy.dart';
import 'package:ivy_pulse/domain/services/queue_worker_strategy.dart';
import 'package:ivy_pulse/presentation/common/display_mode.dart';
import 'package:ivy_pulse/presentation/common/fullscreen.dart';
import 'package:ivy_pulse/presentation/common/widgets/queue_prompt_host.dart';
import 'package:ivy_pulse/presentation/home/home_page.dart';
import 'package:ivy_pulse/presentation/onboarding/onboarding_gate.dart';

class IvyPulseExtension extends LatticeEdgeExtension {
  bool initialized = false;

  @override
  String get id => AppConstants.extensionId;

  @override
  String get name => AppConstants.extensionName;

  @override
  String get description => AppConstants.extensionDescription;

  @override
  ExtensionDisplayMode get defaultDisplayMode => ExtensionDisplayMode.panel;

  /// A walk-around is done on a device held upright, one gloved hand on the
  /// vehicle — the checklist, the fault sheet and the signature pad are all
  /// tall, scrolling forms.
  ///
  /// Only binds once we ship native, where the host constructs this class and
  /// reads the getter. Registered as a web extension we are a WebView behind a
  /// JSON manifest with no orientation field, and the host activity is
  /// `userLandscape` — so today portrait comes from [verticalQuarterTurns]
  /// rotating our own UI, and this is a declaration of intent for the handoff.
  @override
  ExtensionOrientation get preferredOrientation => ExtensionOrientation.portrait;

  @override
  Widget build(ExtensionContext extensionContext) {
    if (!initialized) {
      configureDependencies(extensionContext);
      // Start draining anything parked from a previous run before the operator
      // does anything — a queued PMCS is stale the moment it sits.
      unawaited(
        getIt<QueueWorkerStrategy>().start().catchError((Object e) {
          debugPrint('[IvyPulse] queue worker start failed: $e');
        }),
      );
      initialized = true;
    }
    return Theme(
      data: appTheme,
      child: ValueListenableBuilder<int>(
        // Testing lever only — see [verticalQuarterTurns]. RotatedBox turns at
        // layout time, so at 1 or 3 the whole UI is handed portrait
        // constraints rather than a landscape box with sideways pixels.
        valueListenable: verticalQuarterTurns,
        builder: (context, turns, child) =>
            RotatedBox(quarterTurns: turns, child: child),
        child: QueuePromptHost(
          promptStrategy: getIt<QueuePromptStrategy>(),
          child: IvyPulseExtensionUI(extensionContext: extensionContext),
        ),
      ),
    );
  }
}

class IvyPulseExtensionUI extends StatefulWidget {
  final ExtensionContext extensionContext;
  const IvyPulseExtensionUI({super.key, required this.extensionContext});

  @override
  State<IvyPulseExtensionUI> createState() => IvyPulseExtensionUIState();
}

class IvyPulseExtensionUIState extends State<IvyPulseExtensionUI> {
  StreamSubscription<IncomingMessage>? messageSub;

  /// Height of the strip reserved for the exit control in full screen.
  static const double exitBarHeight = minTouchTarget + 16;

  @override
  void initState() {
    super.initState();
    // The host resets the shared drawer width on every plugin transition, so
    // ask on each open rather than once per install. Harmless where it is
    // ignored, and it only ever widens the drawer — the whole screen comes
    // from [claimScreenOnFirstTouch].
    WidgetsBinding.instance.addPostFrameCallback((_) => widenPanel());
    widget.extensionContext.messaging.markAllAsRead();
    messageSub =
        widget.extensionContext.messaging.onMessageReceived.listen((_) {
      widget.extensionContext.messaging.markAllAsRead();
    });
  }

  /// Ask the host for the full content area.
  ///
  /// Host 0.9.0 ignores this from a web extension — the JS bridge it injects
  /// exposes no `ui.setPanelSize`, so the SDK's call resolves to null and
  /// `getPanelSize` answers with its `small` default rather than an error.
  /// Verified against the live bridge. Left in place because it costs one
  /// silent call and starts working the day the host bridges it; the log line
  /// says plainly which host we are on.
  Future<void> widenPanel() async {
    final ui = widget.extensionContext.ui;
    try {
      await ui.setPanelSize(PanelSize.large);
      final actual = await ui.getPanelSize();
      if (actual != PanelSize.large) {
        debugPrint('[IvyPulse] host kept the panel ${actual.name} — '
            'no panel-size support on this host build');
      }
    } catch (e) {
      debugPrint('[IvyPulse] panel resize failed: $e');
    }
  }

  @override
  void dispose() {
    messageSub?.cancel();
    super.dispose();
  }

  /// Take the whole device on the operator's first touch.
  ///
  /// The browser only grants full screen off transient user activation, so
  /// there is no claiming it when the extension loads — this is as close to
  /// "on open" as the platform allows, and a walk-around starts with a tap
  /// (a platform, a bumper number) regardless. Translucent, so the tap that
  /// buys us the screen still reaches whatever it was aimed at.
  ///
  /// Hung off pointer *up*, not down. A touch `pointerdown` carries no
  /// transient activation in Chrome — wiring it too just logged
  /// `API can only be initiated by a user gesture` on every touch — while the
  /// release does, which is why the tested-good path was a button's
  /// `onPressed`.
  ///
  /// Not latched. This used to remember the first granted claim and never
  /// ask again, which meant the CAC scan — a separate camera activity that
  /// makes the browser drop fullscreen — left the operator stranded in the
  /// panel afterwards. Now it asks whenever the operator wants full screen
  /// and does not have it, so the first tap after the camera returns takes
  /// the screen back. A deliberate exit clears [fullScreenWanted] and is
  /// left alone.
  void claimScreen() {
    if (!fullScreenWanted.value || fullScreenOn.value) return;
    unawaited(enterFullScreen());
  }

  /// Give the screen back and close the plugin.
  ///
  /// Full screen hides the host's own header, so its back arrow and ✕ are
  /// gone — without this the operator has no way out but the Profile tab.
  /// Leave full screen first: if the close is refused we have at least handed
  /// the host chrome back rather than leaving them sealed in.
  ///
  /// The host knows us by its own registration id (`web_ivy_pulse` for a web
  /// deploy), not by [AppConstants.extensionId], so ask it who is active
  /// rather than asserting a name.
  Future<void> exitPlugin() async {
    // A deliberate exit — do not take the screen back on the next tap.
    fullScreenWanted.value = false;
    await leaveFullScreen();
    final ui = widget.extensionContext.ui;
    try {
      final active = await ui.getActiveExtension();
      await ui.closeExtension(active ?? AppConstants.extensionId);
    } catch (e) {
      debugPrint('[IvyPulse] close failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: (_) => claimScreen(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full screen takes the host's header away, so reserve the strip it
          // used to occupy: it keeps the exit control off the first row of
          // controls (it was landing on the JLTV card) and holds the UI clear
          // of the status-bar cutout.
          ValueListenableBuilder<bool>(
            valueListenable: fullScreenOn,
            builder: (context, on, child) => Padding(
              padding: EdgeInsets.only(top: on ? exitBarHeight : 0),
              child: child,
            ),
            child: const OnboardingGate(child: HomePage()),
          ),
          // Inside the rotation, so it sits top-right as the operator sees it.
          ValueListenableBuilder<bool>(
            valueListenable: fullScreenOn,
            builder: (context, on, child) => on ? child! : const SizedBox(),
            child: SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Material(
                    color: bgDark.withValues(alpha: 0.85),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: exitPlugin,
                      customBorder: const CircleBorder(),
                      // Gloved thumb, and the only way out of full screen.
                      child: const SizedBox(
                        width: minTouchTarget,
                        height: minTouchTarget,
                        child: Icon(Icons.close, size: 22, color: textPrimary),
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
