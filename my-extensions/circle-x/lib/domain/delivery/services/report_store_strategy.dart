import 'package:circle_x/domain/delivery/services/pmcs_entity_port.dart';
import 'package:circle_x/domain/delivery/services/remote_report_source.dart';

abstract class ReportStoreStrategy
    implements PmcsEntityPort, RemoteReportSource {}
