import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/cac_ocr.dart';

void main() {
  const custom = CacOcrTheme(
    text: Color(0xFF000001),
    mutedText: Color(0xFF000002),
    surface: Color(0xFF000003),
    raisedSurface: Color(0xFF000004),
    outline: Color(0xFF000005),
    accent: Color(0xFF000006),
    success: Color(0xFF000007),
    successContainer: Color(0xFF000008),
    warning: Color(0xFF000009),
    warningContainer: Color(0xFF00000A),
    danger: Color(0xFF00000B),
    dangerContainer: Color(0xFF00000C),
  );

  Future<CacOcrTheme> resolve(WidgetTester tester, ThemeData theme) async {
    late CacOcrTheme resolved;
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Builder(builder: (context) {
        resolved = CacOcrTheme.of(context);
        return const SizedBox();
      }),
    ));
    return resolved;
  }

  testWidgets('without an extension the colours follow the colour scheme',
      (tester) async {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
    final resolved = await resolve(tester, ThemeData(colorScheme: scheme));

    expect(resolved.text, scheme.onSurface);
    expect(resolved.mutedText, scheme.onSurfaceVariant);
    expect(resolved.accent, scheme.primary);
    expect(resolved.outline, scheme.outlineVariant);
    expect(resolved.danger, scheme.error);
    expect(resolved.dangerContainer, scheme.error.withValues(alpha: 0.15));
  });

  testWidgets('a registered extension wins over the colour scheme',
      (tester) async {
    final resolved =
        await resolve(tester, ThemeData(extensions: const [custom]));

    expect(resolved, same(custom));
  });

  test('light and dark schemes get their own status tones', () {
    final light = CacOcrTheme.fromColorScheme(
        ColorScheme.fromSeed(seedColor: Colors.indigo));
    final dark = CacOcrTheme.fromColorScheme(ColorScheme.fromSeed(
        seedColor: Colors.indigo, brightness: Brightness.dark));

    expect(light.success, isNot(dark.success));
    expect(light.warning, isNot(dark.warning));
    expect(dark.successContainer, dark.success.withValues(alpha: 0.15));
  });

  test('copyWith replaces only what it is given', () {
    final changed = custom.copyWith(accent: Colors.red, danger: Colors.pink);

    expect(changed.accent, Colors.red);
    expect(changed.danger, Colors.pink);
    expect(changed.copyWith().text, custom.text);
    expect(changed.mutedText, custom.mutedText);
    expect(changed.warningContainer, custom.warningContainer);
  });

  test('lerp blends every colour and keeps itself against nothing', () {
    final white = custom.copyWith(
      text: Colors.white,
      mutedText: Colors.white,
      surface: Colors.white,
      raisedSurface: Colors.white,
      outline: Colors.white,
      accent: Colors.white,
      success: Colors.white,
      successContainer: Colors.white,
      warning: Colors.white,
      warningContainer: Colors.white,
      danger: Colors.white,
      dangerContainer: Colors.white,
    );

    expect(custom.lerp(white, 0).text, custom.text);
    expect(custom.lerp(white, 1).danger, Colors.white);
    expect(custom.lerp(white, 0.5).surface,
        Color.lerp(custom.surface, Colors.white, 0.5));
    expect(custom.lerp(null, 0.5), same(custom));
  });
}
