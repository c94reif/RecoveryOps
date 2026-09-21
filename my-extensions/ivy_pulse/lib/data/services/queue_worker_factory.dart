import 'package:flutter/foundation.dart';
import 'package:ivy_pulse/data/services/isolate_queue_worker.dart';
import 'package:ivy_pulse/data/services/main_thread_queue_worker.dart';
import 'package:ivy_pulse/domain/repositories/queued_submissions_repo.dart';
import 'package:ivy_pulse/domain/services/mesh_broadcaster_port.dart';
import 'package:ivy_pulse/domain/services/pmcs_entity_port.dart';
import 'package:ivy_pulse/domain/services/queue_prompt_strategy.dart';
import 'package:ivy_pulse/domain/services/queue_worker_strategy.dart';

QueueWorkerStrategy createQueueWorker({
  required QueuedSubmissionsRepository repository,
  required PmcsEntityPort entityPort,
  required MeshBroadcasterPort meshPort,
  required QueuePromptStrategy promptStrategy,
}) =>
    kIsWeb
        ? MainThreadQueueWorker(
            repository: repository,
            entityPort: entityPort,
            meshPort: meshPort,
            promptStrategy: promptStrategy,
          )
        : IsolateQueueWorker(
            repository: repository,
            entityPort: entityPort,
            meshPort: meshPort,
            promptStrategy: promptStrategy,
          );
