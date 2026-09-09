import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_ops/domain/entities/profile.dart';
import 'package:recovery_ops/domain/repositories/profile_repo.dart';
import 'package:recovery_ops/presentation/profile/profile_view_model.dart';

class FakeProfileRepository implements ProfileRepository {
  Profile? _stored;

  @override
  Future<Profile?> getProfile() async => _stored;

  @override
  Future<void> saveProfile(Profile profile) async {
    _stored = profile;
  }
}

void main() {
  late FakeProfileRepository repo;
  late ProfileViewModel vm;

  setUp(() {
    repo = FakeProfileRepository();
    vm = ProfileViewModel(repo);
  });

  test('initial state is loading', () {
    expect(vm.isLoading, isTrue);
    expect(vm.isDirty, isFalse);
    expect(vm.hasExistingProfile, isFalse);
  });

  test('loadProfile with empty DB sets isLoading false', () async {
    await vm.loadProfile();

    expect(vm.isLoading, isFalse);
    expect(vm.hasExistingProfile, isFalse);
    expect(vm.savedName, '');
    expect(vm.savedCallSign, '');
    expect(vm.savedUnit, '');
  });

  test('loadProfile with existing profile populates saved values', () async {
    repo._stored =
        const Profile(name: 'Jane', callSign: 'Wraith', unit: 'Bravo');

    await vm.loadProfile();

    expect(vm.isLoading, isFalse);
    expect(vm.hasExistingProfile, isTrue);
    expect(vm.savedName, 'Jane');
    expect(vm.savedCallSign, 'Wraith');
    expect(vm.savedUnit, 'Bravo');
  });

  test('checkDirty sets isDirty when values differ from saved', () async {
    await vm.loadProfile();

    vm.checkDirty('John', '', '');
    expect(vm.isDirty, isTrue);
  });

  test('checkDirty clears isDirty when values match saved', () async {
    await vm.loadProfile();

    vm.checkDirty('John', '', '');
    expect(vm.isDirty, isTrue);

    vm.checkDirty('', '', '');
    expect(vm.isDirty, isFalse);
  });

  test('checkDirty does not notify when dirty state unchanged', () async {
    await vm.loadProfile();

    int notifyCount = 0;
    vm.addListener(() => notifyCount++);

    vm.checkDirty('X', '', '');
    expect(notifyCount, 1);

    vm.checkDirty('Y', '', '');
    expect(notifyCount, 1);
  });

  test('save with empty fields sets validation snackbar', () async {
    await vm.loadProfile();

    await vm.save('', 'Ghost', 'Alpha');

    expect(vm.snackBarMessage, 'All fields are required');
    expect(vm.hasExistingProfile, isFalse);
  });

  test('save persists to repository and updates state', () async {
    await vm.loadProfile();

    await vm.save('John', 'Ghost', 'Alpha');

    expect(vm.snackBarMessage, 'Profile Saved!');
    expect(vm.hasExistingProfile, isTrue);
    expect(vm.isDirty, isFalse);
    expect(vm.savedName, 'John');
    expect(vm.savedCallSign, 'Ghost');
    expect(vm.savedUnit, 'Alpha');

    final stored = await repo.getProfile();
    expect(stored!.name, 'John');
  });

  test('save then checkDirty with same values is not dirty', () async {
    await vm.loadProfile();
    await vm.save('John', 'Ghost', 'Alpha');

    vm.checkDirty('John', 'Ghost', 'Alpha');
    expect(vm.isDirty, isFalse);
  });

  test('notifyListeners fires on loadProfile', () async {
    int notifyCount = 0;
    vm.addListener(() => notifyCount++);

    await vm.loadProfile();

    expect(notifyCount, 1);
  });

  test('notifyListeners fires on save', () async {
    await vm.loadProfile();

    int notifyCount = 0;
    vm.addListener(() => notifyCount++);

    await vm.save('John', 'Ghost', 'Alpha');

    expect(notifyCount, 1);
  });

  test('save with all empty fields sets validation snackbar', () async {
    await vm.loadProfile();
    await vm.save('', '', '');
    expect(vm.snackBarMessage, 'All fields are required');
  });

  test('save with only callSign empty still succeeds', () async {
    await vm.loadProfile();
    await vm.save('John', '', 'Alpha');
    expect(vm.snackBarMessage, 'Profile Saved!');
  });

  test('save with only unit empty sets validation snackbar', () async {
    await vm.loadProfile();
    await vm.save('John', 'Ghost', '');
    expect(vm.snackBarMessage, 'All fields are required');
  });

  test('snackBarMessage is null initially', () {
    expect(vm.snackBarMessage, isNull);
  });

  test('loadProfile resets isDirty', () async {
    await vm.loadProfile();
    vm.checkDirty('changed', '', '');
    expect(vm.isDirty, isTrue);

    await vm.loadProfile();
    expect(vm.isDirty, isFalse);
  });

  test('checkDirty with all three fields changed is dirty', () async {
    await vm.loadProfile();
    vm.checkDirty('a', 'b', 'c');
    expect(vm.isDirty, isTrue);
  });

  test('save updates savedName, savedCallSign, savedUnit', () async {
    await vm.loadProfile();
    await vm.save('A', 'B', 'C');
    expect(vm.savedName, 'A');
    expect(vm.savedCallSign, 'B');
    expect(vm.savedUnit, 'C');
  });

  test('save followed by save overwrites previous values', () async {
    await vm.loadProfile();
    await vm.save('First', 'F1', 'U1');
    await vm.save('Second', 'F2', 'U2');

    expect(vm.savedName, 'Second');
    final stored = await repo.getProfile();
    expect(stored!.name, 'Second');
  });

  test('checkDirty after save with new values detects difference', () async {
    await vm.loadProfile();
    await vm.save('John', 'Ghost', 'Alpha');
    vm.checkDirty('John', 'Ghost', 'Bravo');
    expect(vm.isDirty, isTrue);
  });
}
