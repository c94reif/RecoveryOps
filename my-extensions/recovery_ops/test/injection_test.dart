import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_ops/data/datasources/local/database.dart';
import 'package:recovery_ops/data/dao/profile/profile_dao.dart';
import 'package:recovery_ops/data/dao/reports/reports_dao.dart';
import 'package:recovery_ops/domain/repositories/profile_repo.dart';
import 'package:recovery_ops/domain/repositories/reports_repo.dart';
import 'package:recovery_ops/domain/repositories/location_repo.dart';
import 'package:recovery_ops/presentation/profile/profile_view_model.dart';
import 'package:recovery_ops/presentation/home/home_view_model.dart';
import 'package:recovery_ops/presentation/recovery/recovery_view_model.dart';
import 'package:recovery_ops/presentation/navigation/navigation_view_model.dart';
import 'package:recovery_ops/presentation/reports/reports_view_model.dart';
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
