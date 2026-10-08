import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/domain/entities/fault_severity.dart';
import 'package:circle_x/domain/entities/maintainer_review.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/domain/entities/profile.dart';
import 'package:circle_x/domain/services/pmcs_report_notifier.dart';

import '../../support/fake_pmcs_notifications.dart';
import '../../support/fakes.dart';

void main() {
  late FakeReportsRepository reports;
  late FakeProfileRepository profiles;
  late FakePmcsNotifications notifications;
  PmcsReportNotifier? notifier;

  setUp(() {
    reports = FakeReportsRepository();
    profiles = FakeProfileRepository(
        const Profile(uic: 'WJ8TAA', unitName: 'Alpha', followedUnits: [
      FollowedUnit(uic: 'WAB4C0', name: 'Bravo'),
    ]));
    notifications = FakePmcsNotifications();
    notifier = null;
  });
  tearDown(() => notifier?.dispose());

  Future<PmcsReportNotifier> start({Duration? timeout}) async {
    final service = PmcsReportNotifier(
        reportsRepository: reports,
        profileRepository: profiles,
        notifications: notifications,
        requestTimeout: timeout ?? const Duration(seconds: 1));
    notifier = service;
    await service.settled;
    return service;
  }

  test('old local IDs seed the phone ledger before duplicate arrivals',
      () async {
    final existing =
        buildReport(entityId: 'old', isOutgoing: false, isRead: false);
    reports.reports.add(existing);
    final service = await start();
    await service.received([existing]);
    expect(notifications.remembered, {'old'});
    expect(notifications.attempts, isEmpty);
  });

  test('primary and followed alerts include local alias, bumper and condition',
      () async {
    final service = await start();
    await service.received([
      buildReport(
          entityId: 'primary',
          isOutgoing: false,
          isRead: false,
          faults: [buildFault(severity: FaultSeverity.redX)]),
      buildReport(
          entityId: 'followed',
          bumperNumber: 'B-22',
          uic: ' wab4c0 ',
          isOutgoing: false,
          isRead: false),
    ]);
    expect(notifications.posted, [
      (
        reportId: 'primary',
        title: 'New PMCS: A-11',
        body: 'Alpha (WJ8TAA) · NMC'
      ),
      (
        reportId: 'followed',
        title: 'New PMCS: B-22',
        body: 'Bravo (WAB4C0) · FMC'
      ),
    ]);
  });

  test('outgoing, read, review, foreign and withdrawn records never alert',
      () async {
    final service = await start();
    await reports.withdrawReport('withdrawn');
    await service.received([
      buildReport(entityId: 'outgoing', isRead: false),
      buildReport(entityId: 'read', isOutgoing: false),
      buildReport(
          entityId: 'foreign', uic: 'WOTHER', isOutgoing: false, isRead: false),
      buildReport(entityId: 'withdrawn', isOutgoing: false, isRead: false),
      buildReport(
          entityId: 'review',
          isOutgoing: false,
          isRead: false,
          maintainerReview: MaintainerReview(
              sourceReportId: 'source',
              faults: const [
                FaultReview(
                    itemId: 'engine', phase: PmcsPhase.before, verified: true)
              ],
              signature: buildSignature())),
    ]);
    expect(notifications.posted, isEmpty);
    expect(notifications.remembered,
        {'outgoing', 'read', 'foreign', 'withdrawn', 'review'});
  });

  test('a missing or invalid profile never acts as a wildcard subscription',
      () async {
    profiles.profile = null;
    final service = await start();
    await service.received([
      buildReport(entityId: 'no-profile', isOutgoing: false, isRead: false)
    ]);
    profiles.profile = const Profile(uic: 'BAD');
    await service.received([
      buildReport(entityId: 'invalid-profile', isOutgoing: false, isRead: false)
    ]);
    expect(notifications.posted, isEmpty);
    expect(notifications.remembered, {'no-profile', 'invalid-profile'});
  });

  test('ignored and disabled reports stay consumed after refollow or reenable',
      () async {
    final ignored = buildReport(
        entityId: 'old-foreign',
        uic: 'WOTHER',
        isOutgoing: false,
        isRead: false);
    final disabled =
        buildReport(entityId: 'old-disabled', isOutgoing: false, isRead: false);
    final service = await start();
    await service.received([ignored]);
    notifications.enabled = false;
    await service.received([disabled]);
    service.dispose();
    profiles.profile = const Profile(uic: 'WJ8TAA', followedUnits: [
      FollowedUnit(uic: 'WOTHER', name: 'Attached'),
    ]);
    notifications.enabled = true;
    // Neither report is still local; the native ledger survives local deletion.
    final restarted = await start();
    await restarted.received([ignored, disabled]);
    expect(notifications.posted, isEmpty);
  });

  test('current profile aliases and unit removal apply to new arrivals',
      () async {
    final service = await start();
    profiles.profile = const Profile(uic: 'WAB4C0', unitName: 'New home');
    await service.received([
      buildReport(entityId: 'former-home', isOutgoing: false, isRead: false),
      buildReport(
          entityId: 'new-home',
          uic: 'WAB4C0',
          isOutgoing: false,
          isRead: false),
    ]);
    expect(notifications.posted.single.reportId, 'new-home');
    expect(notifications.posted.single.body, 'New home (WAB4C0) · FMC');
    expect(notifications.remembered, {'former-home', 'new-home'});
  });

  test('overlapping peer and store observations only make one OS attempt',
      () async {
    final service = await start();
    final report = buildReport(isOutgoing: false, isRead: false);
    await Future.wait([
      service.received([report]),
      service.received([report])
    ]);
    expect(notifications.attempts, [report.entityId]);
    expect(notifications.posted, hasLength(1));
  });

  test('withdrawal cancels an alert waiting behind another native request',
      () async {
    final service = await start();
    notifications.showGate = Completer<void>();
    final processing = service.received([
      buildReport(entityId: 'first', isOutgoing: false, isRead: false),
      buildReport(entityId: 'withdrawn', isOutgoing: false, isRead: false),
    ]);
    await Future<void>.delayed(Duration.zero);
    await reports.withdrawReport('withdrawn');
    final remembering = service.remember(['withdrawn']);
    notifications.showGate!.complete();
    await Future.wait([processing, remembering]);
    expect(notifications.posted.map((alert) => alert.reportId), ['first']);
    expect(notifications.remembered, {'first', 'withdrawn'});
  });

  test('baseline DB failure fails closed while remembering later observations',
      () async {
    reports.failHistoryRead = true;
    final service = await start();
    reports.failHistoryRead = false;
    await service.received([
      buildReport(
          entityId: 'uncertain-history', isOutgoing: false, isRead: false)
    ]);
    expect(notifications.attempts, isEmpty);
    expect(notifications.remembered, {'uncertain-history'});
  });

  test('native failures cannot poison later alerts or repeat failed attempts',
      () async {
    final service = await start();
    final failed =
        buildReport(entityId: 'failed', isOutgoing: false, isRead: false);
    notifications.failShow = true;
    notifications.failRemember = true;
    await service.received([failed]);
    notifications.failShow = false;
    notifications.failRemember = false;
    await service.received([
      failed,
      buildReport(entityId: 'next', isOutgoing: false, isRead: false)
    ]);
    expect(notifications.attempts, ['failed', 'next']);
    expect(notifications.posted.single.reportId, 'next');
  });

  test('hung native work times out and later observations still complete',
      () async {
    final service = await start(timeout: const Duration(milliseconds: 20));
    notifications.showGate = Completer<void>();
    await service.received(
        [buildReport(entityId: 'hung', isOutgoing: false, isRead: false)]);
    final hanging = notifications.showGate!;
    notifications.showGate = null;
    await service.received(
        [buildReport(entityId: 'next', isOutgoing: false, isRead: false)]);
    expect(notifications.posted.single.reportId, 'next');
    hanging.complete();
    await Future<void>.delayed(Duration.zero);
    expect(notifications.posted.single.reportId, 'next');
  });

  test('disposal suppresses observations that have not reached the native port',
      () async {
    reports.reports.add(buildReport(entityId: 'old'));
    notifications.rememberGate = Completer<void>();
    final service = PmcsReportNotifier(
        reportsRepository: reports,
        profileRepository: profiles,
        notifications: notifications);
    notifier = service;
    final pending = service.received(
        [buildReport(entityId: 'new', isOutgoing: false, isRead: false)]);
    service.dispose();
    notifications.rememberGate!.complete();
    await pending;
    expect(notifications.attempts, isEmpty);
  });
}
