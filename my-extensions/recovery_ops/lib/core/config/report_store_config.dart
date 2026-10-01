import 'package:le_sdk/le_sdk.dart' as sdk;

/// The deployment must register schemas/report-v1.schema.json at this path.
class ReportStoreConfig {
  static const itemType = sdk.MeshDataTypePath(
    namespace: String.fromEnvironment('REPORT_STORE_NAMESPACE',
        defaultValue: 'sustainment'),
    domain: String.fromEnvironment('REPORT_STORE_DOMAIN',
        defaultValue: 'recovery-ops'),
    dataType: String.fromEnvironment('REPORT_STORE_DATA_TYPE',
        defaultValue: 'recovery-report'),
    version: String.fromEnvironment('REPORT_STORE_VERSION', defaultValue: 'v1'),
  );
}
