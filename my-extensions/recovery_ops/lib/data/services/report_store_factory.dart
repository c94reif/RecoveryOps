import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:recovery_ops/core/config/report_store_config.dart';
import 'package:recovery_ops/data/services/entity_report_store_strategy.dart';
import 'package:recovery_ops/data/services/mesh_item_report_store_strategy.dart';
import 'package:recovery_ops/domain/services/report_store_backend.dart';
import 'package:recovery_ops/domain/services/report_store_strategy.dart';

ReportStoreStrategy createReportStore(
  sdk.ExtensionContext context, {
  ReportStoreBackend? backend,
  sdk.MeshDataTypePath itemType = ReportStoreConfig.itemType,
}) =>
    switch (backend ?? ReportStoreBackend.fromEnvironment()) {
      ReportStoreBackend.meshItemStore => MeshItemReportStoreStrategy(
          items: context.meshItemStore.items, type: itemType),
      ReportStoreBackend.entities =>
        EntityReportStoreStrategy(context.entities),
    };
