import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/data/mappers/pmcs_entity_mapper.dart';
import 'package:ivy_pulse/data/mappers/pmcs_report_codec.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';

import '../support/fakes.dart';
import '../support/inspection_harness.dart';

void main() {
  late InspectionHarness harness;
  const codec = PmcsReportCodec();

  setUp(() {
    clearSnackBars();
    harness = InspectionHarness(reportCodec: codec);
  });
  tearDown(clearSnackBars);

  test(
      'a 155-character description survives review, both transports and queued payloads',
      () async {
    final description = 'Leak at the lower reservoir seam. '.padRight(155, 'x');
    await harness.beginPhase(PmcsPhase.before);
    await harness.viewModel.answer(brakeFluid, 3);
    expect(await harness.viewModel.saveNote(brakeFluid, 'Original description'),
        isTrue);
    await harness.viewModel.answer(parkingBrake, 1);
    await harness.viewModel.completeActivePhase();
    harness.viewModel.openSummary();

    await harness.viewModel.reviewFault(harness.viewModel.sessionFaults.first);
    expect(harness.viewModel.stage, InspectionStage.inspecting);
    expect(harness.viewModel.expandedItemId, brakeFluid.id);
    expect(
        harness.viewModel.results[brakeFluid.id]!.note, 'Original description');
    expect(await harness.viewModel.saveNote(brakeFluid, description), isTrue);
    await harness.viewModel.returnToSummary();
    expect(harness.viewModel.stage, InspectionStage.summary);
    expect(harness.viewModel.sessionFaults.first.note, description);

    harness.entityPort.publishSucceeds = false;
    harness.meshPort.broadcastSucceeds = false;
    await harness.viewModel.submitWith(buildSignature());
    await Future<void>.delayed(Duration.zero);

    expect(harness.viewModel.stage, InspectionStage.submitted);
    final stored = harness.reports.reports.single;
    expect(stored.faults.first.note, description);
    expect(stored.faults.last.note, isNull);
    expect(harness.entityPort.published.single.faults.first.note, description);
    expect(harness.meshPort.broadcast.single.faults.first.note, description);
    expect(harness.queueWorker.enqueued, hasLength(2));
    for (final queued in harness.queueWorker.enqueued) {
      expect(
          codec
              .decodeReport(queued.payload, fromCallsign: 'Mesh')!
              .faults
              .first
              .note,
          description);
      final entity = const PmcsEntityMapper().buildEntity(stored);
      expect(
          const PmcsEntityMapper().parseRemoteEntity(entity)!.faults.first.note,
          description);
    }
  });

  test('overlong descriptions cannot overwrite a saved description', () async {
    await harness.beginPhase(PmcsPhase.before);
    await harness.viewModel.answer(brakeFluid, 1);
    expect(await harness.viewModel.saveNote(brakeFluid, 'Small leak'), isTrue);
    expect(await harness.viewModel.saveNote(brakeFluid, 'x' * 156), isFalse);
    expect(harness.viewModel.results[brakeFluid.id]!.note, 'Small leak');
    final saved =
        await harness.results.getResults('session-1', PmcsPhase.before);
    expect(saved[brakeFluid.id]!.note, 'Small leak');
    expect(await harness.viewModel.saveNote(brakeFluid, '   '), isTrue);
    expect(harness.viewModel.results[brakeFluid.id]!.note, isNull);
  });

  test('dictation respects the same description limit', () async {
    await harness.beginPhase(PmcsPhase.before);
    await harness.viewModel.answer(brakeFluid, 1);
    await harness.viewModel.attachNote(brakeFluid, 'x' * 160);
    expect(harness.viewModel.results[brakeFluid.id]!.note, 'x' * 155);
  });
}
