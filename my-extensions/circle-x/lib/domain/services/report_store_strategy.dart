import 'package:circle_x/domain/services/pmcs_entity_port.dart';
import 'package:circle_x/domain/services/remote_report_source.dart';

/// One strategy supplies both reads and writes to the same remote backend.
/// Existing entityId fields remain stable report IDs for the database/outbox.
abstract class ReportStoreStrategy
    implements PmcsEntityPort, RemoteReportSource {}
