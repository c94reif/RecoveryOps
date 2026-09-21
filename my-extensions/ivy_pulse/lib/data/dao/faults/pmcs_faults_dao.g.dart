// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pmcs_faults_dao.dart';

// ignore_for_file: type=lint
mixin _$PmcsFaultsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PmcsFaultsTable get pmcsFaults => attachedDatabase.pmcsFaults;
  PmcsFaultsDaoManager get managers => PmcsFaultsDaoManager(this);
}

class PmcsFaultsDaoManager {
  final _$PmcsFaultsDaoMixin _db;
  PmcsFaultsDaoManager(this._db);
  $$PmcsFaultsTableTableManager get pmcsFaults =>
      $$PmcsFaultsTableTableManager(_db.attachedDatabase, _db.pmcsFaults);
}
