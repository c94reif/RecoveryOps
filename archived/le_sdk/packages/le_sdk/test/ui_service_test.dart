import 'package:flutter_test/flutter_test.dart';
import 'package:le_sdk/le_sdk.dart';

// Uses StubExtensionContext to test the stub UiService behavior.
void main() {
  late ExtensionContext context;

  setUp(() async {
    context = await StubExtensionContext.connect(timeout: Duration(seconds: 1));
  });

  group('StubUiService', () {
    test('getActiveView returns map by default', () async {
      expect(await context.ui.getActiveView(), 'map');
    });

    test('navigateTo updates active view', () async {
      await context.ui.navigateTo('lca');
      expect(await context.ui.getActiveView(), 'lca');
    });

    test('getActivePanel returns null by default', () async {
      expect(await context.ui.getActivePanel(), isNull);
    });

    test('openPanel and closePanel update active panel', () async {
      await context.ui.openPanel('settings');
      expect(await context.ui.getActivePanel(), 'settings');
      await context.ui.closePanel();
      expect(await context.ui.getActivePanel(), isNull);
    });

    test('getActiveExtension returns null by default', () async {
      expect(await context.ui.getActiveExtension(), isNull);
    });

    test('openExtension and closeExtension update state', () async {
      await context.ui.openExtension('field_report');
      expect(await context.ui.getActiveExtension(), 'field_report');
      await context.ui.closeExtension('field_report');
      expect(await context.ui.getActiveExtension(), isNull);
    });

    test('boolean state queries return false by default', () async {
      expect(await context.ui.isLocationPickerActive(), false);
      expect(await context.ui.isPttActive(), false);
      expect(await context.ui.isStatusBarEnabled(), false);
    });
  });
}
