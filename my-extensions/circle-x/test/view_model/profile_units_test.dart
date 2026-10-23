import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/domain/profile/entities/profile.dart';
import 'package:circle_x/presentation/profile/profile_view_model.dart';

import '../support/fakes.dart';

class DelayedProfileRepository extends FakeProfileRepository {
  bool failRead = false;
  bool failWrite = false;
  Completer<void>? pendingWrite;

  @override
  Future<Profile?> getProfile() async {
    if (failRead) throw StateError('storage unavailable');
    return super.getProfile();
  }

  @override
  Future<void> saveProfile(Profile profile) async {
    await pendingWrite?.future;
    if (failWrite) throw StateError('disk full');
    await super.saveProfile(profile);
  }
}

void main() {
  late DelayedProfileRepository repository;
  late ProfileViewModel viewModel;
  late List<Profile> changes;

  setUp(() async {
    repository = DelayedProfileRepository()
      ..profile = const Profile(uic: 'WJ8TAA', unitName: 'Headquarters');
    changes = [];
    viewModel = ProfileViewModel(repository,
        onSaved: (profile) async => changes.add(profile));
    await viewModel.loadProfile();
  });

  tearDown(() => viewModel.dispose());

  test('followed unit names can be added, edited, reloaded and removed',
      () async {
    expect(await viewModel.addFollowedUnit(' wab4c0 ', name: ' Alpha Company '),
        isTrue);
    expect(viewModel.followedUnits.single.uic, 'WAB4C0');
    expect(viewModel.followedUnits.single.name, 'Alpha Company');
    expect(
        await viewModel.updateFollowedUnit('WAB4C0', 'wab4c1', name: 'Bravo'),
        isTrue);

    final restored = ProfileViewModel(repository);
    addTearDown(restored.dispose);
    await restored.loadProfile();
    expect(restored.savedUic, 'WJ8TAA');
    expect(restored.savedUnitName, 'Headquarters');
    expect(restored.followedUnits.single.label, 'Bravo (WAB4C1)');
    expect(await viewModel.removeFollowedUnit(' wab4c1 '), isTrue);
    expect(repository.profile!.followedUnits, isEmpty);
    expect(changes, hasLength(3));
  });

  test('saving primary UIC or its name preserves the additional units',
      () async {
    await viewModel.addFollowedUnit('WAB4C0', name: 'Alpha');
    expect(await viewModel.save('W12ABC', unitName: ' Battalion '), isTrue);
    expect(repository.profile!.unitName, 'Battalion');
    expect(repository.profile!.followedUnits.single.label, 'Alpha (WAB4C0)');

    await viewModel.save('W12ABD');
    expect(repository.profile!.unitName, 'Battalion');
    expect(repository.profile!.followedUnits.single.uic, 'WAB4C0');
  });

  test('followed-unit edits preserve the primary UIC and its unsaved draft',
      () async {
    viewModel.checkDirty('W12ABC', unitName: 'Pending draft');
    await viewModel.addFollowedUnit('WAB4C0', name: 'Alpha');

    expect(repository.profile!.uic, 'WJ8TAA');
    expect(repository.profile!.unitName, 'Headquarters');
    expect(viewModel.isDirty, isTrue);
    expect(viewModel.savedUic, 'WJ8TAA');
  });

  test('mutations retain settings saved after this view was loaded', () async {
    repository.profile = const Profile(
        uic: 'WJ8TAA',
        unitName: 'Updated elsewhere',
        followedUnits: [FollowedUnit(uic: 'WAB4C0', name: 'Alpha')]);
    await viewModel.save('W12ABC');

    expect(repository.profile!.unitName, 'Updated elsewhere');
    expect(repository.profile!.followedUnits.single.uic, 'WAB4C0');
  });

  test('duplicates including the primary are refused before persistence',
      () async {
    expect(await viewModel.addFollowedUnit('wj8taa'), isFalse);
    expect(repository.saved, isEmpty);
    await viewModel.addFollowedUnit('WAB4C0', name: 'Alpha');
    expect(await viewModel.addFollowedUnit(' wab4c0 '), isFalse);
    expect(await viewModel.updateFollowedUnit('WAB4C0', 'WJ8TAA'), isFalse);
    expect(await viewModel.save('wab4c0'), isFalse);
    expect(repository.saved, hasLength(1));
    expect(repository.profile!.uic, 'WJ8TAA');
    expect(repository.profile!.followedUnits.single.name, 'Alpha');
  });

  test('renaming an existing followed UIC does not count as a duplicate',
      () async {
    await viewModel.addFollowedUnit('WAB4C0');
    expect(viewModel.followedUnitError('wab4c0', editingUic: 'WAB4C0'), isNull);
    expect(
        await viewModel.updateFollowedUnit('WAB4C0', 'wab4c0', name: 'Alpha'),
        isTrue);
    expect(repository.profile!.followedUnits.single.name, 'Alpha');
  });

  test('UIC whitespace aliases work for saving, duplicate checks and edits',
      () async {
    expect(await viewModel.save(' wj 8\ttaa '), isTrue);
    expect(viewModel.savedUic, 'WJ8TAA');
    viewModel.checkDirty('w j8taa');
    expect(viewModel.isDirty, isFalse);

    expect(await viewModel.addFollowedUnit(' wa\u00a0b4 c0 ', name: 'Alpha'),
        isTrue);
    expect(viewModel.followedUnits.single.uic, 'WAB4C0');
    expect(
        viewModel.followedUnitError('wa b4c0'), 'You already follow this UIC.');
    expect(await viewModel.addFollowedUnit('wa b4c0'), isFalse);
    expect(await viewModel.addFollowedUnit('w j8taa'), isFalse);
    expect(
        viewModel.followedUnitError('wa b4c0', editingUic: 'wab4 c0'), isNull);
    expect(
        await viewModel.updateFollowedUnit('wab4 c0', 'wa b4c0', name: 'Bravo'),
        isTrue);
    expect(viewModel.followedUnits.single.name, 'Bravo');
    expect(await viewModel.removeFollowedUnit('wab4 c0'), isTrue);
    expect(repository.profile!.followedUnits, isEmpty);
  });

  test('invalid UICs and removal of the primary never change the profile',
      () async {
    for (final uic in ['', 'W123', 'W123456', 'W12!45']) {
      expect(await viewModel.addFollowedUnit(uic), isFalse);
    }
    expect(await viewModel.removeFollowedUnit('WJ8TAA'), isFalse);
    expect(repository.saved, isEmpty);
    expect(changes, isEmpty);
  });

  test('save failure keeps names and subscriptions available for retry',
      () async {
    repository.failWrite = true;
    expect(await viewModel.addFollowedUnit('WAB4C0', name: 'Alpha'), isFalse);
    expect(viewModel.isSaving, isFalse);
    expect(viewModel.savedUnitName, 'Headquarters');
    expect(viewModel.followedUnits, isEmpty);
    expect(viewModel.errorMessage, contains('Could not save'));
    expect(changes, isEmpty);

    repository.failWrite = false;
    expect(await viewModel.addFollowedUnit('WAB4C0', name: 'Alpha'), isTrue);
    expect(changes, hasLength(1));
  });

  test('in-flight saves cannot be overwritten by a second operation', () async {
    repository.pendingWrite = Completer<void>();
    final saving = viewModel.addFollowedUnit('WAB4C0', name: 'Alpha');
    expect(viewModel.isSaving, isTrue);
    expect(await viewModel.save('W12ABC'), isFalse);
    repository.pendingWrite!.complete();
    expect(await saving, isTrue);

    expect(repository.saved, hasLength(1));
    expect(repository.profile!.uic, 'WJ8TAA');
    expect(viewModel.isSaving, isFalse);
  });

  test('load failure finishes loading and permits a successful retry',
      () async {
    repository.failRead = true;
    await viewModel.loadProfile();
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.savedUnitName, 'Headquarters');
    expect(viewModel.errorMessage, contains('Could not load'));

    repository.failRead = false;
    await viewModel.loadProfile();
    expect(viewModel.errorMessage, isNull);
  });

  test('only changing the local primary name makes the form dirty', () {
    viewModel.checkDirty('WJ8TAA', unitName: 'HQ');
    expect(viewModel.isDirty, isTrue);
    viewModel.checkDirty('WJ8TAA', unitName: ' Headquarters ');
    expect(viewModel.isDirty, isFalse);
  });
}
