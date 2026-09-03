import 'dart:async';

import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';
import 'package:recovery_ops/core/di/injection.dart';
import 'package:recovery_ops/core/theme/appTheme.dart';
import 'package:recovery_ops/domain/services/queuePromptStrategy.dart';
import 'package:recovery_ops/domain/services/queueWorkerStrategy.dart';
import 'package:recovery_ops/presentation/common/widgets/queuePromptHost.dart';
import 'package:recovery_ops/presentation/home/homePage.dart';

class RecoveryOpsExtension extends LatticeEdgeExtension {
  bool initialized = false;

  @override
  String get id => 'recovery_ops';

  @override
  String get name => 'Recovery Ops';

  @override
  String get description => 'Recovery Operations for Lattice Edge';

  @override
  ExtensionDisplayMode get defaultDisplayMode => ExtensionDisplayMode.panel;

  @override
  Widget build(ExtensionContext extensionContext) {
    if (!initialized) {
      configureDependencies(extensionContext);
      unawaited(
        getIt<QueueWorkerStrategy>().start().catchError((Object e) {
          debugPrint('[RecoveryOps] queue worker start failed: $e');
        }),
      );
      initialized = true;
    }
    return Theme(
      data: appTheme,
      child: QueuePromptHost(
        promptStrategy: getIt<QueuePromptStrategy>(),
        child: RecoveryOpsExtensionUI(extensionContext: extensionContext),
      ),
    );
  }
}

class RecoveryOpsExtensionUI extends StatefulWidget {
  final ExtensionContext extensionContext;
  const RecoveryOpsExtensionUI({super.key, required this.extensionContext});

  @override
  State<RecoveryOpsExtensionUI> createState() => RecoveryOpsExtensionUIState();
}

class RecoveryOpsExtensionUIState extends State<RecoveryOpsExtensionUI> {
  StreamSubscription<IncomingMessage>? messageSub;

  @override
  void initState() {
    super.initState();
    widget.extensionContext.messaging.markAllAsRead();
    messageSub = widget.extensionContext.messaging.onMessageReceived.listen((_) {
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
