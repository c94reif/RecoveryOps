import 'package:flutter_test/flutter_test.dart';
import 'package:ivy_pulse/domain/entities/profile.dart';
import 'package:ivy_pulse/presentation/profile/profile_view_model.dart';

import '../support/fakes.dart';

void main() {
  late FakeProfileRepository repository;
  late ProfileViewModel viewModel;

  setUp(() {
    repository = FakeProfileRepository();
    viewModel = ProfileViewModel(repository);
  });

  group('loading', () {
    test('an empty device leaves the UIC blank and the profile unsaved',
        () async {
      await viewModel.loadProfile();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.hasExistingProfile, isFalse);
      expect(viewModel.savedUic, '');
    });

    test('a stored UIC is restored so the operator does not retype it',
        () async {
      repository.profile = const Profile(uic: 'WJ8TAA');

      await viewModel.loadProfile();

      expect(viewModel.hasExistingProfile, isTrue);
      expect(viewModel.savedUic, 'WJ8TAA');
      expect(viewModel.isDirty, isFalse);
    });

    test('the page stays on its spinner until the load returns', () {
      expect(viewModel.isLoading, isTrue);
    });
  });

  group('dirty tracking', () {
    setUp(() async {
      repository.profile = const Profile(uic: 'WJ8TAA');
      await viewModel.loadProfile();
    });

    test('re-reading the stored value is not an edit', () {
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.checkDirty('WJ8TAA');

      expect(viewModel.isDirty, isFalse);
      expect(notifications, 0);
    });

    test('changing the UIC marks the profile dirty', () {
      viewModel.checkDirty('WAB4C0');

      expect(viewModel.isDirty, isTrue);
    });

    test('retyping the stored UIC in lower case is still not an edit', () {
      // The UIC is stored upper case, so the operator fighting a soft keyboard
      // must not be shown a Save Edit button for work they did not do.
      viewModel.checkDirty('wj8taa');

      expect(viewModel.isDirty, isFalse);
    });

    test('typing back to the stored value clears the dirty flag', () {
      viewModel.checkDirty('WJ8TA');
      expect(viewModel.isDirty, isTrue);

      viewModel.checkDirty('WJ8TAA');

      expect(viewModel.isDirty, isFalse);
    });

    test('a second edit while already dirty does not notify again', () {
      viewModel.checkDirty('WJ8TA');
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.checkDirty('WJ8T');

      expect(viewModel.isDirty, isTrue);
      expect(notifications, 0);
    });
  });

  group('saving', () {
    setUp(() async {
      await viewModel.loadProfile();
    });

    test('an empty UIC is refused and says why', () async {
      await viewModel.save('');

      expect(viewModel.snackBarMessage, 'UIC is required');
      expect(repository.saved, isEmpty);
      expect(viewModel.hasExistingProfile, isFalse);
    });

    test('a UIC that is only whitespace is refused', () async {
      await viewModel.save('   ');

      expect(viewModel.snackBarMessage, 'UIC is required');
      expect(repository.saved, isEmpty);
    });

    test('a save stores the UIC upper case and clears the dirty flag',
        () async {
      viewModel.checkDirty('wj8taa');
      await viewModel.save('  wj8taa  ');

      expect(viewModel.isDirty, isFalse);
      expect(viewModel.snackBarMessage, 'Profile Saved!');
      expect(repository.saved.single.uic, 'WJ8TAA');
    });

    test('the first save flips the profile to an existing one', () async {
      expect(viewModel.hasExistingProfile, isFalse);

      await viewModel.save('WJ8TAA');

      expect(viewModel.hasExistingProfile, isTrue);
    });

    test('after a save the same value is no longer an edit', () async {
      await viewModel.save('WJ8TAA');

      viewModel.checkDirty('WJ8TAA');

      expect(viewModel.isDirty, isFalse);
    });

    test('a refused save leaves the stored profile untouched', () async {
      await viewModel.save('WJ8TAA');

      await viewModel.save('');

      expect(viewModel.savedUic, 'WJ8TAA');
      expect(repository.saved, hasLength(1));
      expect(repository.profile!.uic, 'WJ8TAA');
    });
  });
}
