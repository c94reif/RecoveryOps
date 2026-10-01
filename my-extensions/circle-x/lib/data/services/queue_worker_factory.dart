import 'package:circle_x/domain/services/user_notification_sink.dart';
import 'package:circle_x/domain/services/delivery_coordinator.dart';
import 'package:flutter/foundation.dart';
import 'package:circle_x/data/services/isolate_queue_worker.dart';
import 'package:circle_x/data/services/main_thread_queue_worker.dart';
import 'package:circle_x/domain/repositories/queued_submissions_repo.dart';
import 'package:circle_x/domain/services/mesh_broadcaster_port.dart';
import 'package:circle_x/domain/services/pmcs_entity_port.dart';
import 'package:circle_x/domain/services/queue_prompt_strategy.dart';
import 'package:circle_x/domain/services/queue_worker_strategy.dart';

QueueWorkerStrategy createQueueWorker({
  required QueuedSubmissionsRepository repository,
  required PmcsEntityPort entityPort,
  required MeshBroadcasterPort meshPort,
  required QueuePromptStrategy promptStrategy,
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
