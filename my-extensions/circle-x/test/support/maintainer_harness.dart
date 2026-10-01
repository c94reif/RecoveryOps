import 'package:circle_x/data/mappers/pmcs_report_codec.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/services/cac_scanner_strategy.dart';
import 'package:circle_x/domain/services/clock.dart';
import 'package:circle_x/domain/services/speech_recognition_strategy.dart';
import 'package:circle_x/domain/usecases/identity/parse_cac_barcode.dart';
import 'package:circle_x/domain/usecases/identity/verify_operator_identity.dart';
import 'package:circle_x/domain/usecases/publishing/publish_pmcs_report.dart';
import 'package:circle_x/domain/usecases/reporting/submit_maintainer_review.dart';
import 'package:circle_x/presentation/maintainer/maintainer_review_view_model.dart';

import 'fakes.dart';
import 'inspection_harness.dart' show FakeSpeechRecognition;

class MaintainerHarness {
  final repository = FakeReportsRepository();
  final queue = FakeQueuedSubmissionsRepository();
  final worker = FakeQueueWorker();
  final store = FakePmcsEntityPort();
  final peers = FakeMeshBroadcaster();
  final scanner = FakeCacScanner();
  final speech = FakeSpeechRecognition();
  final clock = FixedClock(DateTime.utc(2026, 9, 30));
  late final PmcsReport report;
  late final SubmitMaintainerReview submit;
  late final PublishPmcsReport publish;

  MaintainerHarness() {
    report = buildReport(entityId: 'original', faults: [
      buildFault(itemId: 'engine', note: 'Operator note'),
      buildFault(itemId: 'brakes', subcategory: 'Brake lines'),
    ]);
    repository.reports.add(report);
    submit = SubmitMaintainerReview(
        reports: repository,
        queue: queue,
        worker: worker,
        transaction: FakeTransactionRunner(),
        codec: const PmcsReportCodec(),
        clock: clock);
    publish = PublishPmcsReport(
        entityPort: store,
        meshPort: peers,
        queueWorker: worker,
        codec: const PmcsReportCodec(),
        clock: clock);
    scanner.willRead('1087987498');
  }

  VerifyOperatorIdentity verify(CacScannerStrategy scanner) =>
      VerifyOperatorIdentity(
          scanner: scanner, parseBarcode: ParseCacBarcode(clock));

  MaintainerReviewViewModel model(
          {CacScannerStrategy? withScanner,
          SpeechRecognitionStrategy? withSpeech}) =>
      MaintainerReviewViewModel(
          report: report,
          reviewId: 'review-id',
          submitReview: submit,
          publish: publish,
          onSaved: (_) async {},
          scanner: withScanner ?? scanner,
          speech: withSpeech ?? speech,
          verifyIdentity: verify(withScanner ?? scanner));
}
