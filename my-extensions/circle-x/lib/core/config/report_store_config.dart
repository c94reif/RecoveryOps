import 'package:le_sdk/le_sdk.dart' as sdk;

class ReportStoreConfig {
  static const itemType = sdk.MeshDataTypePath(
    namespace: String.fromEnvironment('REPORT_STORE_NAMESPACE',
        defaultValue: 'sustainment'),
    domain:
        String.fromEnvironment('REPORT_STORE_DOMAIN', defaultValue: 'circle-x'),
    dataType: String.fromEnvironment('REPORT_STORE_DATA_TYPE',
        defaultValue: 'pmcs-report'),
    version: String.fromEnvironment('REPORT_STORE_VERSION', defaultValue: 'v1'),
  );
}
