import 'dart:async';

import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';
import 'package:ivy_pulse/core/constants/app_constants.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/services/queue_prompt_strategy.dart';
import 'package:ivy_pulse/domain/services/queue_worker_strategy.dart';
import 'package:ivy_pulse/presentation/common/widgets/queue_prompt_host.dart';
import 'package:ivy_pulse/presentation/home/home_page.dart';

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

  @override
  void initState() {
    super.initState();
    widget.extensionContext.messaging.markAllAsRead();
    messageSub =
        widget.extensionContext.messaging.onMessageReceived.listen((_) {
      widget.extensionContext.messaging.markAllAsRead();
    });
  }

  @override
  void dispose() {
    messageSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const HomePage();
  }
}
