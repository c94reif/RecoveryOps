import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/domain/entities/cac_scan.dart';
import 'package:circle_x/domain/services/cac_scanner_strategy.dart';

import '../support/maintainer_harness.dart';

class ControlledCacScanner implements CacScannerStrategy {
  final captures = <Completer<CacCapture>>[];
  @override
  Future<CacCapture> capture() {
    final next = Completer<CacCapture>();
    captures.add(next);
    return next.future;
  }

  @override
  Future<void> cancel() async {}
  @override
  Future<bool> isAvailable() async => true;
}

void main() {
  test(
      'finishing decisions keeps the current card and supports note-only edits',
      () {
    final h = MaintainerHarness();
    final model = h.model();
    addTearDown(model.dispose);
    model.decide(true);
    expect(model.index, 1);
    expect(model.complete, isFalse);
    model.decide(false);
    expect(model.index, 1);
    expect(model.complete, isTrue);
    model.select(0);
    model.describe('Updated note');
    expect(model.descriptions.first, 'Updated note');
    expect(model.decisions, [true, false]);
    model.requestSignature();
    model.edit();
    expect(model.signing, isFalse);
    expect(model.index, 0);
    model.decide(false);
    expect(model.index, 1);
    model.decide(true);
    expect(model.index, 0);
    expect(model.decisions, [false, true]);
  });

  test('every decision is required and the batch cannot save without a CAC',
      () async {
    final h = MaintainerHarness();
    final model = h.model();
    addTearDown(model.dispose);
    model.decide(true);
    model.requestSignature();
    expect(model.signing, isFalse);
    await model.scanAndSubmit();
    expect(h.scanner.captureCalls, 0);

    // Returning to the same reviewed fault cannot count as reviewing another.
    model.select(0);
    model.decide(false);
    model.requestSignature();
    await model.scanAndSubmit();
    expect(model.reviewedCount, 1);
    expect(model.complete, isFalse);
    expect(model.signing, isFalse);
    expect(h.scanner.captureCalls, 0);
    expect(h.queue.submissions, isEmpty);

    model.decide(false);
    model.requestSignature();
    h.scanner.willFail(CacRejection.noCamera);
    await model.scanAndSubmit();
    expect(model.saved, isNull);
    expect(h.repository.reports, hasLength(1));
    expect(h.queue.submissions, isEmpty);
    expect(h.peers.broadcast, isEmpty);
    expect(model.decisions, [false, false]);
  });

  test('a cancelled stale scan cannot sign an edited batch or a later scan',
      () async {
    final h = MaintainerHarness();
    final scanner = ControlledCacScanner();
    final model = h.model(withScanner: scanner);
    addTearDown(model.dispose);
    model.decide(true);
    model.decide(false);
    model.requestSignature();
    final first = model.scanAndSubmit();
    model.cancelScan();
    model.edit();
    model.describe('Edited after cancelling');
    model.requestSignature();
    final second = model.scanAndSubmit();
    scanner.captures.first.complete(const CacCapture.read('1087987498'));
    await first;
    expect(model.saved, isNull);
    expect(h.queue.submissions, isEmpty);
    scanner.captures.last.complete(const CacCapture.read('1087987499'));
    await second;
    expect(model.saved!.maintainerReview!.signature.dodId, '1087987499');
    expect(model.saved!.maintainerReview!.faults.last.description,
        'Edited after cancelling');
    expect(h.repository.reports, hasLength(2));
  });

  test('leaving during a scan never saves or sends its late result', () async {
    final h = MaintainerHarness();
    final scanner = ControlledCacScanner();
    final model = h.model(withScanner: scanner);
    model.decide(true);
    model.decide(false);
    model.requestSignature();
    final submission = model.scanAndSubmit();
    model.dispose();
    scanner.captures.single.complete(const CacCapture.read('1087987498'));
    await submission;
    expect(h.repository.reports, hasLength(1));
    expect(h.queue.submissions, isEmpty);
    expect(h.peers.broadcast, isEmpty);
  });

  test('repeat submit is ignored and a storage failure keeps the draft',
      () async {
    final h = MaintainerHarness();
    final model = h.model();
    addTearDown(model.dispose);
    model.describe('Verified a leak');
    model.decide(true);
    model.decide(false);
    model.requestSignature();
    h.repository.failInsert = true;
    await model.scanAndSubmit();
    expect(model.saved, isNull);
    expect(model.descriptions.first, 'Verified a leak');
    expect(model.error, isNotNull);
    h.repository.failInsert = false;
    await model.scanAndSubmit();
    await model.scanAndSubmit();
    expect(h.scanner.captureCalls, 2);
    expect(h.repository.reports, hasLength(2));
    expect(h.queue.submissions, hasLength(2));
    expect(h.peers.broadcast, hasLength(1));
  });
}
