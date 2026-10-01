import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:circle_x/core/config/report_store_config.dart';
import 'package:circle_x/data/services/entity_report_store_strategy.dart';
import 'package:circle_x/data/services/mesh_item_report_store_strategy.dart';
import 'package:circle_x/domain/services/report_store_backend.dart';
import 'package:circle_x/domain/services/report_store_strategy.dart';

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
