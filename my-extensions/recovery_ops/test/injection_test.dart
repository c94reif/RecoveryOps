import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_ops/data/datasources/local/database.dart';
import 'package:recovery_ops/data/dao/profile/profileDao.dart';
import 'package:recovery_ops/data/dao/reports/reportsDao.dart';
import 'package:recovery_ops/domain/repositories/profileRepo.dart';
import 'package:recovery_ops/domain/repositories/reportsRepo.dart';
import 'package:recovery_ops/domain/repositories/locationRepo.dart';
import 'package:recovery_ops/presentation/profile/profileViewModel.dart';
import 'package:recovery_ops/presentation/home/homeViewModel.dart';
import 'package:recovery_ops/presentation/recovery/recoveryViewModel.dart';
import 'package:recovery_ops/presentation/navigation/navigationViewModel.dart';
import 'package:recovery_ops/presentation/reports/reportsViewModel.dart';
import 'package:recovery_ops/core/di/injection.dart';

void main() {

  setUp(() async {
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('configureDependencies registers AppDatabase',
      skip: 'requires ExtensionContext from Lattice Edge runtime', () {
    expect(getIt.isRegistered<AppDatabase>(), isTrue);
  });

  test('configureDependencies registers ProfileDao',
      skip: 'requires ExtensionContext from Lattice Edge runtime', () {
    expect(getIt.isRegistered<ProfileDao>(), isTrue);
  });

  test('configureDependencies registers ReportsDao',
      skip: 'requires ExtensionContext from Lattice Edge runtime', () {
    expect(getIt.isRegistered<ReportsDao>(), isTrue);
  });

  test('configureDependencies registers repositories',
      skip: 'requires ExtensionContext from Lattice Edge runtime', () {
    expect(getIt.isRegistered<ProfileRepository>(), isTrue);
    expect(getIt.isRegistered<ReportsRepository>(), isTrue);
    expect(getIt.isRegistered<LocationRepository>(), isTrue);
  });

  test('configureDependencies registers ViewModels',
      skip: 'requires ExtensionContext from Lattice Edge runtime', () {
    expect(getIt.isRegistered<ProfileViewModel>(), isTrue);
    expect(getIt.isRegistered<HomeViewModel>(), isTrue);
    expect(getIt.isRegistered<RecoveryViewModel>(), isTrue);
    expect(getIt.isRegistered<NavigationViewModel>(), isTrue);
    expect(getIt.isRegistered<ReportsViewModel>(), isTrue);
  });

  test('AppDatabase is registered as a singleton',
      skip: 'requires ExtensionContext from Lattice Edge runtime', () {
    final db1 = getIt<AppDatabase>();
    final db2 = getIt<AppDatabase>();
    expect(identical(db1, db2), isTrue);
  });
}
