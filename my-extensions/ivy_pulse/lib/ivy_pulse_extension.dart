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

  @override
  ExtensionOrientation get preferredOrientation =>
      ExtensionOrientation.portrait;

  @override
  Widget build(ExtensionContext extensionContext) {
    if (!initialized) {
      configureDependencies(extensionContext);
      unawaited(
        getIt<QueueWorkerStrategy>().start().catchError((Object error) {
          debugPrint('[IvyPulse] queue worker start failed: $error');
        }),
      );
      initialized = true;
    }
    return Theme(
      data: appTheme,
      child: QueuePromptHost(
        promptStrategy: getIt<QueuePromptStrategy>(),
        child: IvyPulseExtensionUI(extensionContext: extensionContext),
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

  static const double exitBarHeight = minTouchTarget + 16;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widenPanel());
    widget.extensionContext.messaging.markAllAsRead();
    messageSub =
        widget.extensionContext.messaging.onMessageReceived.listen((_) {
      widget.extensionContext.messaging.markAllAsRead();
    });
  }

  Future<void> widenPanel() async {
    final ui = widget.extensionContext.ui;
    try {
      await ui.setPanelSize(PanelSize.large);
      final actual = await ui.getPanelSize();
      if (actual != PanelSize.large) {
        debugPrint('[IvyPulse] host kept the panel ${actual.name} — '
            'no panel-size support on this host build');
      }
    } catch (error) {
      debugPrint('[IvyPulse] panel resize failed: $error');
    }
  }

  @override
  void dispose() {
    messageSub?.cancel();
    super.dispose();
  }

  void claimScreen() {
    if (!fullScreenWanted.value || fullScreenOn.value) return;
    unawaited(enterFullScreen());
  }

  Future<void> exitPlugin() async {
    fullScreenWanted.value = false;
    await leaveFullScreen();
    final ui = widget.extensionContext.ui;
    try {
      final active = await ui.getActiveExtension();
      await ui.closeExtension(active ?? AppConstants.extensionId);
    } catch (error) {
      debugPrint('[IvyPulse] close failed: $error');
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
          ValueListenableBuilder<bool>(
            valueListenable: fullScreenOn,
            builder: (context, isFullScreen, child) => Padding(
              padding: EdgeInsets.only(top: isFullScreen ? exitBarHeight : 0),
              child: child,
            ),
            child: const OnboardingGate(child: HomePage()),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: fullScreenOn,
            builder: (context, isFullScreen, child) =>
                isFullScreen ? child! : const SizedBox(),
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
