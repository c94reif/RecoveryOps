import 'package:flutter_test/flutter_test.dart';
import 'package:le_sdk/le_sdk.dart';

void main() {
  late StubExtensionContext ctx;

  setUp(() {
    ctx = StubExtensionContext();
  });

  group('StubExtensionContext', () {
    test('hostInfo returns standalone defaults', () {
      final info = ctx.hostInfo;
      expect(info.host, 'standalone');
      expect(info.version, '0.0.0');
      expect(info.extensionId, 'preview');
      expect(info.callsign, 'CALLSIGN-01');
    });

    test('map.pickLocation returns coordinates near base location', () async {
      final loc = await ctx.map.pickLocation();
      expect(loc, isNotNull);
      // Stub returns random offset from base (33.6937, -117.9165)
      expect(loc!.latitude, closeTo(33.6937, 0.01));
      expect(loc.longitude, closeTo(-117.9165, 0.02));
    });

    test('map.addMarker is a no-op', () async {
      await ctx.map.addMarker(const LatLng(0, 0), label: 'test');
    });

    test('speech.dictate returns null', () async {
      expect(await ctx.speech.dictate(), isNull);
    });

    test('storage round-trip: write then read', () async {
      await ctx.storage.write('key', 'value');
      expect(await ctx.storage.read('key'), 'value');
    });

    test('storage.read returns null for missing key', () async {
      expect(await ctx.storage.read('nope'), isNull);
    });

    test('storage.delete deletes key', () async {
      await ctx.storage.write('k', 'v');
      await ctx.storage.delete('k');
      expect(await ctx.storage.read('k'), isNull);
    });

    test('accessors are cached (same instance)', () {
      expect(identical(ctx.map, ctx.map), isTrue);
      expect(identical(ctx.storage, ctx.storage), isTrue);
    });

    test('close is a no-op', () {
      ctx.close(); // should not throw
    });
  });

  group('HostInfo.fromJson', () {
    test('parses canonical fields', () {
      final info = HostInfo.fromJson({
        'host': 'test',
        'version': '1.0.0',
        'extensionId': 'my_ext',
      });
      expect(info.extensionId, 'my_ext');
    });

    test('falls back to pluginId', () {
      final info = HostInfo.fromJson({
        'host': 'test',
        'version': '1.0.0',
        'pluginId': 'legacy_id',
      });
      expect(info.extensionId, 'legacy_id');
    });

    test('parses callsign when present', () {
      final info = HostInfo.fromJson({
        'host': 'test',
        'version': '1.0.0',
        'extensionId': 'ext',
        'callsign': 'ALPHA-1',
      });
      expect(info.callsign, 'ALPHA-1');
    });

    test('callsign is null when absent', () {
      final info = HostInfo.fromJson({
        'host': 'test',
        'version': '1.0.0',
        'extensionId': 'ext',
      });
      expect(info.callsign, isNull);
    });
  });
}
