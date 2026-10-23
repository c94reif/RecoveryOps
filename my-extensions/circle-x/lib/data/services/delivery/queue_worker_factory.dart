import 'package:circle_x/domain/shared/services/user_notification_sink.dart';
import 'package:circle_x/domain/delivery/services/delivery_coordinator.dart';
import 'package:flutter/foundation.dart';
import 'package:circle_x/data/services/delivery/isolate_queue_worker.dart';
import 'package:circle_x/data/services/delivery/main_thread_queue_worker.dart';
import 'package:circle_x/domain/delivery/repositories/queued_submissions_repo.dart';
import 'package:circle_x/domain/delivery/services/mesh_broadcaster_port.dart';
import 'package:circle_x/domain/delivery/services/pmcs_entity_port.dart';
import 'package:circle_x/domain/delivery/services/queue_prompt_strategy.dart';
import 'package:circle_x/domain/delivery/services/queue_worker_strategy.dart';

QueueWorkerStrategy createQueueWorker({
  required QueuedSubmissionsRepository repository,
  required PmcsEntityPort entityPort,
  required MeshBroadcasterPort meshPort,
  QueuePromptStrategy? promptStrategy,
  DeliveryCoordinator? delivery,
  UserNotificationSink notifications = const SilentNotificationSink(),
}) =>
    kIsWeb
        ? MainThreadQueueWorker(
            repository: repository,
            snackBarService: notifications,
            delivery: delivery,
            entityPort: entityPort,
            meshPort: meshPort,
            promptStrategy: promptStrategy,
          )
        : IsolateQueueWorker(
            repository: repository,
            snackBarService: notifications,
            delivery: delivery,
            entityPort: entityPort,
            meshPort: meshPort,
            promptStrategy: promptStrategy,
          );
