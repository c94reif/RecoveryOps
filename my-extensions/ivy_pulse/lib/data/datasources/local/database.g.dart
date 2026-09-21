// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ProfilesTable extends Profiles
    with TableInfo<$ProfilesTable, ProfileData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _uicMeta = const VerificationMeta('uic');
  @override
  late final GeneratedColumn<String> uic = GeneratedColumn<String>(
      'uic', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, uic];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(Insertable<ProfileData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uic')) {
      context.handle(
          _uicMeta, uic.isAcceptableOrUnknown(data['uic']!, _uicMeta));
    } else if (isInserting) {
      context.missing(_uicMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      uic: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uic'])!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class ProfileData extends DataClass implements Insertable<ProfileData> {
  final int id;

  /// Unit Identification Code. The only thing the profile holds — the
  /// operator's identity comes off their CAC when the PMCS is closed out.
  final String uic;
  const ProfileData({required this.id, required this.uic});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uic'] = Variable<String>(uic);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      uic: Value(uic),
    );
  }

  factory ProfileData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileData(
      id: serializer.fromJson<int>(json['id']),
      uic: serializer.fromJson<String>(json['uic']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uic': serializer.toJson<String>(uic),
    };
  }

  ProfileData copyWith({int? id, String? uic}) => ProfileData(
        id: id ?? this.id,
        uic: uic ?? this.uic,
      );
  ProfileData copyWithCompanion(ProfilesCompanion data) {
    return ProfileData(
      id: data.id.present ? data.id.value : this.id,
      uic: data.uic.present ? data.uic.value : this.uic,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileData(')
          ..write('id: $id, ')
          ..write('uic: $uic')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, uic);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileData && other.id == this.id && other.uic == this.uic);
}

class ProfilesCompanion extends UpdateCompanion<ProfileData> {
  final Value<int> id;
  final Value<String> uic;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.uic = const Value.absent(),
  });
  ProfilesCompanion.insert({
    this.id = const Value.absent(),
    required String uic,
  }) : uic = Value(uic);
  static Insertable<ProfileData> custom({
    Expression<int>? id,
    Expression<String>? uic,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uic != null) 'uic': uic,
    });
  }

  ProfilesCompanion copyWith({Value<int>? id, Value<String>? uic}) {
    return ProfilesCompanion(
      id: id ?? this.id,
      uic: uic ?? this.uic,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uic.present) {
      map['uic'] = Variable<String>(uic.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('uic: $uic')
          ..write(')'))
        .toString();
  }
}

class $PmcsSessionsTable extends PmcsSessions
    with TableInfo<$PmcsSessionsTable, PmcsSessionData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PmcsSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _bumperNumberMeta =
      const VerificationMeta('bumperNumber');
  @override
  late final GeneratedColumn<String> bumperNumber = GeneratedColumn<String>(
      'bumper_number', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _vehicleTypeMeta =
      const VerificationMeta('vehicleType');
  @override
  late final GeneratedColumn<String> vehicleType = GeneratedColumn<String>(
      'vehicle_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operatorMeta =
      const VerificationMeta('operator');
  @override
  late final GeneratedColumn<String> operator = GeneratedColumn<String>(
      'operator', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _uicMeta = const VerificationMeta('uic');
  @override
  late final GeneratedColumn<String> uic = GeneratedColumn<String>(
      'uic', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _submittedAtMeta =
      const VerificationMeta('submittedAt');
  @override
  late final GeneratedColumn<DateTime> submittedAt = GeneratedColumn<DateTime>(
      'submitted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _completedPhasesMeta =
      const VerificationMeta('completedPhases');
  @override
  late final GeneratedColumn<String> completedPhases = GeneratedColumn<String>(
      'completed_phases', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('IN_PROGRESS'));
  static const VerificationMeta _signatureJsonMeta =
      const VerificationMeta('signatureJson');
  @override
  late final GeneratedColumn<String> signatureJson = GeneratedColumn<String>(
      'signature_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sessionId,
        bumperNumber,
        vehicleType,
        operator,
        uic,
        startedAt,
        submittedAt,
        completedPhases,
        status,
        signatureJson,
        latitude,
        longitude
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pmcs_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<PmcsSessionData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('bumper_number')) {
      context.handle(
          _bumperNumberMeta,
          bumperNumber.isAcceptableOrUnknown(
              data['bumper_number']!, _bumperNumberMeta));
    } else if (isInserting) {
      context.missing(_bumperNumberMeta);
    }
    if (data.containsKey('vehicle_type')) {
      context.handle(
          _vehicleTypeMeta,
          vehicleType.isAcceptableOrUnknown(
              data['vehicle_type']!, _vehicleTypeMeta));
    } else if (isInserting) {
      context.missing(_vehicleTypeMeta);
    }
    if (data.containsKey('operator')) {
      context.handle(_operatorMeta,
          operator.isAcceptableOrUnknown(data['operator']!, _operatorMeta));
    } else if (isInserting) {
      context.missing(_operatorMeta);
    }
    if (data.containsKey('uic')) {
      context.handle(
          _uicMeta, uic.isAcceptableOrUnknown(data['uic']!, _uicMeta));
    } else if (isInserting) {
      context.missing(_uicMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('submitted_at')) {
      context.handle(
          _submittedAtMeta,
          submittedAt.isAcceptableOrUnknown(
              data['submitted_at']!, _submittedAtMeta));
    }
    if (data.containsKey('completed_phases')) {
      context.handle(
          _completedPhasesMeta,
          completedPhases.isAcceptableOrUnknown(
              data['completed_phases']!, _completedPhasesMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('signature_json')) {
      context.handle(
          _signatureJsonMeta,
          signatureJson.isAcceptableOrUnknown(
              data['signature_json']!, _signatureJsonMeta));
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PmcsSessionData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PmcsSessionData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      bumperNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bumper_number'])!,
      vehicleType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}vehicle_type'])!,
      operator: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operator'])!,
      uic: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uic'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      submittedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}submitted_at']),
      completedPhases: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}completed_phases'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      signatureJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}signature_json']),
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude']),
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude']),
    );
  }

  @override
  $PmcsSessionsTable createAlias(String alias) {
    return $PmcsSessionsTable(attachedDatabase, alias);
  }
}

class PmcsSessionData extends DataClass implements Insertable<PmcsSessionData> {
  final int id;

  /// UUID the results, faults and published entity all hang off of.
  final String sessionId;
  final String bumperNumber;
  final String vehicleType;
  final String operator;

  /// Unit Identification Code, carried from the profile.
  final String uic;
  final DateTime startedAt;
  final DateTime? submittedAt;

  /// Comma-joined phase wire names; empty until the first phase is closed.
  final String completedPhases;
  final String status;

  /// `PmcsSignature.toMap()` as JSON — who closed this PMCS out and whether
  /// a CAC backed it up. Null until the session is submitted.
  final String? signatureJson;

  /// Where the walk-around started. Nullable — the host location bridge is
  /// allowed to be unavailable rather than block a PMCS.
  final double? latitude;
  final double? longitude;
  const PmcsSessionData(
      {required this.id,
      required this.sessionId,
      required this.bumperNumber,
      required this.vehicleType,
      required this.operator,
      required this.uic,
      required this.startedAt,
      this.submittedAt,
      required this.completedPhases,
      required this.status,
      this.signatureJson,
      this.latitude,
      this.longitude});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['bumper_number'] = Variable<String>(bumperNumber);
    map['vehicle_type'] = Variable<String>(vehicleType);
    map['operator'] = Variable<String>(operator);
    map['uic'] = Variable<String>(uic);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || submittedAt != null) {
      map['submitted_at'] = Variable<DateTime>(submittedAt);
    }
    map['completed_phases'] = Variable<String>(completedPhases);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || signatureJson != null) {
      map['signature_json'] = Variable<String>(signatureJson);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    return map;
  }

  PmcsSessionsCompanion toCompanion(bool nullToAbsent) {
    return PmcsSessionsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      bumperNumber: Value(bumperNumber),
      vehicleType: Value(vehicleType),
      operator: Value(operator),
      uic: Value(uic),
      startedAt: Value(startedAt),
      submittedAt: submittedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(submittedAt),
      completedPhases: Value(completedPhases),
      status: Value(status),
      signatureJson: signatureJson == null && nullToAbsent
          ? const Value.absent()
          : Value(signatureJson),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
    );
  }

  factory PmcsSessionData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PmcsSessionData(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      bumperNumber: serializer.fromJson<String>(json['bumperNumber']),
      vehicleType: serializer.fromJson<String>(json['vehicleType']),
      operator: serializer.fromJson<String>(json['operator']),
      uic: serializer.fromJson<String>(json['uic']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      submittedAt: serializer.fromJson<DateTime?>(json['submittedAt']),
      completedPhases: serializer.fromJson<String>(json['completedPhases']),
      status: serializer.fromJson<String>(json['status']),
      signatureJson: serializer.fromJson<String?>(json['signatureJson']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'bumperNumber': serializer.toJson<String>(bumperNumber),
      'vehicleType': serializer.toJson<String>(vehicleType),
      'operator': serializer.toJson<String>(operator),
      'uic': serializer.toJson<String>(uic),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'submittedAt': serializer.toJson<DateTime?>(submittedAt),
      'completedPhases': serializer.toJson<String>(completedPhases),
      'status': serializer.toJson<String>(status),
      'signatureJson': serializer.toJson<String?>(signatureJson),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
    };
  }

  PmcsSessionData copyWith(
          {int? id,
          String? sessionId,
          String? bumperNumber,
          String? vehicleType,
          String? operator,
          String? uic,
          DateTime? startedAt,
          Value<DateTime?> submittedAt = const Value.absent(),
          String? completedPhases,
          String? status,
          Value<String?> signatureJson = const Value.absent(),
          Value<double?> latitude = const Value.absent(),
          Value<double?> longitude = const Value.absent()}) =>
      PmcsSessionData(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        bumperNumber: bumperNumber ?? this.bumperNumber,
        vehicleType: vehicleType ?? this.vehicleType,
        operator: operator ?? this.operator,
        uic: uic ?? this.uic,
        startedAt: startedAt ?? this.startedAt,
        submittedAt: submittedAt.present ? submittedAt.value : this.submittedAt,
        completedPhases: completedPhases ?? this.completedPhases,
        status: status ?? this.status,
        signatureJson:
            signatureJson.present ? signatureJson.value : this.signatureJson,
        latitude: latitude.present ? latitude.value : this.latitude,
        longitude: longitude.present ? longitude.value : this.longitude,
      );
  PmcsSessionData copyWithCompanion(PmcsSessionsCompanion data) {
    return PmcsSessionData(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      bumperNumber: data.bumperNumber.present
          ? data.bumperNumber.value
          : this.bumperNumber,
      vehicleType:
          data.vehicleType.present ? data.vehicleType.value : this.vehicleType,
      operator: data.operator.present ? data.operator.value : this.operator,
      uic: data.uic.present ? data.uic.value : this.uic,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      submittedAt:
          data.submittedAt.present ? data.submittedAt.value : this.submittedAt,
      completedPhases: data.completedPhases.present
          ? data.completedPhases.value
          : this.completedPhases,
      status: data.status.present ? data.status.value : this.status,
      signatureJson: data.signatureJson.present
          ? data.signatureJson.value
          : this.signatureJson,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PmcsSessionData(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('bumperNumber: $bumperNumber, ')
          ..write('vehicleType: $vehicleType, ')
          ..write('operator: $operator, ')
          ..write('uic: $uic, ')
          ..write('startedAt: $startedAt, ')
          ..write('submittedAt: $submittedAt, ')
          ..write('completedPhases: $completedPhases, ')
          ..write('status: $status, ')
          ..write('signatureJson: $signatureJson, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      sessionId,
      bumperNumber,
      vehicleType,
      operator,
      uic,
      startedAt,
      submittedAt,
      completedPhases,
      status,
      signatureJson,
      latitude,
      longitude);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PmcsSessionData &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.bumperNumber == this.bumperNumber &&
          other.vehicleType == this.vehicleType &&
          other.operator == this.operator &&
          other.uic == this.uic &&
          other.startedAt == this.startedAt &&
          other.submittedAt == this.submittedAt &&
          other.completedPhases == this.completedPhases &&
          other.status == this.status &&
          other.signatureJson == this.signatureJson &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude);
}

class PmcsSessionsCompanion extends UpdateCompanion<PmcsSessionData> {
  final Value<int> id;
  final Value<String> sessionId;
  final Value<String> bumperNumber;
  final Value<String> vehicleType;
  final Value<String> operator;
  final Value<String> uic;
  final Value<DateTime> startedAt;
  final Value<DateTime?> submittedAt;
  final Value<String> completedPhases;
  final Value<String> status;
  final Value<String?> signatureJson;
  final Value<double?> latitude;
  final Value<double?> longitude;
  const PmcsSessionsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.bumperNumber = const Value.absent(),
    this.vehicleType = const Value.absent(),
    this.operator = const Value.absent(),
    this.uic = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.submittedAt = const Value.absent(),
    this.completedPhases = const Value.absent(),
    this.status = const Value.absent(),
    this.signatureJson = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
  });
  PmcsSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String sessionId,
    required String bumperNumber,
    required String vehicleType,
    required String operator,
    required String uic,
    required DateTime startedAt,
    this.submittedAt = const Value.absent(),
    this.completedPhases = const Value.absent(),
    this.status = const Value.absent(),
    this.signatureJson = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
  })  : sessionId = Value(sessionId),
        bumperNumber = Value(bumperNumber),
        vehicleType = Value(vehicleType),
        operator = Value(operator),
        uic = Value(uic),
        startedAt = Value(startedAt);
  static Insertable<PmcsSessionData> custom({
    Expression<int>? id,
    Expression<String>? sessionId,
    Expression<String>? bumperNumber,
    Expression<String>? vehicleType,
    Expression<String>? operator,
    Expression<String>? uic,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? submittedAt,
    Expression<String>? completedPhases,
    Expression<String>? status,
    Expression<String>? signatureJson,
    Expression<double>? latitude,
    Expression<double>? longitude,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (bumperNumber != null) 'bumper_number': bumperNumber,
      if (vehicleType != null) 'vehicle_type': vehicleType,
      if (operator != null) 'operator': operator,
      if (uic != null) 'uic': uic,
      if (startedAt != null) 'started_at': startedAt,
      if (submittedAt != null) 'submitted_at': submittedAt,
      if (completedPhases != null) 'completed_phases': completedPhases,
      if (status != null) 'status': status,
      if (signatureJson != null) 'signature_json': signatureJson,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
  }

  PmcsSessionsCompanion copyWith(
      {Value<int>? id,
      Value<String>? sessionId,
      Value<String>? bumperNumber,
      Value<String>? vehicleType,
      Value<String>? operator,
      Value<String>? uic,
      Value<DateTime>? startedAt,
      Value<DateTime?>? submittedAt,
      Value<String>? completedPhases,
      Value<String>? status,
      Value<String?>? signatureJson,
      Value<double?>? latitude,
      Value<double?>? longitude}) {
    return PmcsSessionsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      bumperNumber: bumperNumber ?? this.bumperNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      operator: operator ?? this.operator,
      uic: uic ?? this.uic,
      startedAt: startedAt ?? this.startedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      completedPhases: completedPhases ?? this.completedPhases,
      status: status ?? this.status,
      signatureJson: signatureJson ?? this.signatureJson,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (bumperNumber.present) {
      map['bumper_number'] = Variable<String>(bumperNumber.value);
    }
    if (vehicleType.present) {
      map['vehicle_type'] = Variable<String>(vehicleType.value);
    }
    if (operator.present) {
      map['operator'] = Variable<String>(operator.value);
    }
    if (uic.present) {
      map['uic'] = Variable<String>(uic.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (submittedAt.present) {
      map['submitted_at'] = Variable<DateTime>(submittedAt.value);
    }
    if (completedPhases.present) {
      map['completed_phases'] = Variable<String>(completedPhases.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (signatureJson.present) {
      map['signature_json'] = Variable<String>(signatureJson.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PmcsSessionsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('bumperNumber: $bumperNumber, ')
          ..write('vehicleType: $vehicleType, ')
          ..write('operator: $operator, ')
          ..write('uic: $uic, ')
          ..write('startedAt: $startedAt, ')
          ..write('submittedAt: $submittedAt, ')
          ..write('completedPhases: $completedPhases, ')
          ..write('status: $status, ')
          ..write('signatureJson: $signatureJson, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude')
          ..write(')'))
        .toString();
  }
}

class $CheckResultsTable extends CheckResults
    with TableInfo<$CheckResultsTable, CheckResultData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CheckResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _phaseMeta = const VerificationMeta('phase');
  @override
  late final GeneratedColumn<String> phase = GeneratedColumn<String>(
      'phase', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _faultIndexMeta =
      const VerificationMeta('faultIndex');
  @override
  late final GeneratedColumn<int> faultIndex = GeneratedColumn<int>(
      'fault_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _faultLabelMeta =
      const VerificationMeta('faultLabel');
  @override
  late final GeneratedColumn<String> faultLabel = GeneratedColumn<String>(
      'fault_label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _severityMeta =
      const VerificationMeta('severity');
  @override
  late final GeneratedColumn<String> severity = GeneratedColumn<String>(
      'severity', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _recordedAtMeta =
      const VerificationMeta('recordedAt');
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
      'recorded_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sessionId,
        phase,
        itemId,
        faultIndex,
        faultLabel,
        severity,
        note,
        recordedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'check_results';
  @override
  VerificationContext validateIntegrity(Insertable<CheckResultData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('phase')) {
      context.handle(
          _phaseMeta, phase.isAcceptableOrUnknown(data['phase']!, _phaseMeta));
    } else if (isInserting) {
      context.missing(_phaseMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('fault_index')) {
      context.handle(
          _faultIndexMeta,
          faultIndex.isAcceptableOrUnknown(
              data['fault_index']!, _faultIndexMeta));
    } else if (isInserting) {
      context.missing(_faultIndexMeta);
    }
    if (data.containsKey('fault_label')) {
      context.handle(
          _faultLabelMeta,
          faultLabel.isAcceptableOrUnknown(
              data['fault_label']!, _faultLabelMeta));
    } else if (isInserting) {
      context.missing(_faultLabelMeta);
    }
    if (data.containsKey('severity')) {
      context.handle(_severityMeta,
          severity.isAcceptableOrUnknown(data['severity']!, _severityMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
          _recordedAtMeta,
          recordedAt.isAcceptableOrUnknown(
              data['recorded_at']!, _recordedAtMeta));
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {sessionId, phase, itemId},
      ];
  @override
  CheckResultData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CheckResultData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      phase: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phase'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      faultIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}fault_index'])!,
      faultLabel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}fault_label'])!,
      severity: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}severity']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      recordedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}recorded_at'])!,
    );
  }

  @override
  $CheckResultsTable createAlias(String alias) {
    return $CheckResultsTable(attachedDatabase, alias);
  }
}

class CheckResultData extends DataClass implements Insertable<CheckResultData> {
  final int id;
  final String sessionId;
  final String phase;
  final String itemId;
  final int faultIndex;
  final String faultLabel;

  /// Null when the check came back serviceable — no fault, no symbol.
  final String? severity;
  final String? note;
  final DateTime recordedAt;
  const CheckResultData(
      {required this.id,
      required this.sessionId,
      required this.phase,
      required this.itemId,
      required this.faultIndex,
      required this.faultLabel,
      this.severity,
      this.note,
      required this.recordedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['phase'] = Variable<String>(phase);
    map['item_id'] = Variable<String>(itemId);
    map['fault_index'] = Variable<int>(faultIndex);
    map['fault_label'] = Variable<String>(faultLabel);
    if (!nullToAbsent || severity != null) {
      map['severity'] = Variable<String>(severity);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    return map;
  }

  CheckResultsCompanion toCompanion(bool nullToAbsent) {
    return CheckResultsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      phase: Value(phase),
      itemId: Value(itemId),
      faultIndex: Value(faultIndex),
      faultLabel: Value(faultLabel),
      severity: severity == null && nullToAbsent
          ? const Value.absent()
          : Value(severity),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      recordedAt: Value(recordedAt),
    );
  }

  factory CheckResultData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CheckResultData(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      phase: serializer.fromJson<String>(json['phase']),
      itemId: serializer.fromJson<String>(json['itemId']),
      faultIndex: serializer.fromJson<int>(json['faultIndex']),
      faultLabel: serializer.fromJson<String>(json['faultLabel']),
      severity: serializer.fromJson<String?>(json['severity']),
      note: serializer.fromJson<String?>(json['note']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'phase': serializer.toJson<String>(phase),
      'itemId': serializer.toJson<String>(itemId),
      'faultIndex': serializer.toJson<int>(faultIndex),
      'faultLabel': serializer.toJson<String>(faultLabel),
      'severity': serializer.toJson<String?>(severity),
      'note': serializer.toJson<String?>(note),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
    };
  }

  CheckResultData copyWith(
          {int? id,
          String? sessionId,
          String? phase,
          String? itemId,
          int? faultIndex,
          String? faultLabel,
          Value<String?> severity = const Value.absent(),
          Value<String?> note = const Value.absent(),
          DateTime? recordedAt}) =>
      CheckResultData(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        phase: phase ?? this.phase,
        itemId: itemId ?? this.itemId,
        faultIndex: faultIndex ?? this.faultIndex,
        faultLabel: faultLabel ?? this.faultLabel,
        severity: severity.present ? severity.value : this.severity,
        note: note.present ? note.value : this.note,
        recordedAt: recordedAt ?? this.recordedAt,
      );
  CheckResultData copyWithCompanion(CheckResultsCompanion data) {
    return CheckResultData(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      phase: data.phase.present ? data.phase.value : this.phase,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      faultIndex:
          data.faultIndex.present ? data.faultIndex.value : this.faultIndex,
      faultLabel:
          data.faultLabel.present ? data.faultLabel.value : this.faultLabel,
      severity: data.severity.present ? data.severity.value : this.severity,
      note: data.note.present ? data.note.value : this.note,
      recordedAt:
          data.recordedAt.present ? data.recordedAt.value : this.recordedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CheckResultData(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('phase: $phase, ')
          ..write('itemId: $itemId, ')
          ..write('faultIndex: $faultIndex, ')
          ..write('faultLabel: $faultLabel, ')
          ..write('severity: $severity, ')
          ..write('note: $note, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, phase, itemId, faultIndex,
      faultLabel, severity, note, recordedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CheckResultData &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.phase == this.phase &&
          other.itemId == this.itemId &&
          other.faultIndex == this.faultIndex &&
          other.faultLabel == this.faultLabel &&
          other.severity == this.severity &&
          other.note == this.note &&
          other.recordedAt == this.recordedAt);
}

class CheckResultsCompanion extends UpdateCompanion<CheckResultData> {
  final Value<int> id;
  final Value<String> sessionId;
  final Value<String> phase;
  final Value<String> itemId;
  final Value<int> faultIndex;
  final Value<String> faultLabel;
  final Value<String?> severity;
  final Value<String?> note;
  final Value<DateTime> recordedAt;
  const CheckResultsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.phase = const Value.absent(),
    this.itemId = const Value.absent(),
    this.faultIndex = const Value.absent(),
    this.faultLabel = const Value.absent(),
    this.severity = const Value.absent(),
    this.note = const Value.absent(),
    this.recordedAt = const Value.absent(),
  });
  CheckResultsCompanion.insert({
    this.id = const Value.absent(),
    required String sessionId,
    required String phase,
    required String itemId,
    required int faultIndex,
    required String faultLabel,
    this.severity = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime recordedAt,
  })  : sessionId = Value(sessionId),
        phase = Value(phase),
        itemId = Value(itemId),
        faultIndex = Value(faultIndex),
        faultLabel = Value(faultLabel),
        recordedAt = Value(recordedAt);
  static Insertable<CheckResultData> custom({
    Expression<int>? id,
    Expression<String>? sessionId,
    Expression<String>? phase,
    Expression<String>? itemId,
    Expression<int>? faultIndex,
    Expression<String>? faultLabel,
    Expression<String>? severity,
    Expression<String>? note,
    Expression<DateTime>? recordedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (phase != null) 'phase': phase,
      if (itemId != null) 'item_id': itemId,
      if (faultIndex != null) 'fault_index': faultIndex,
      if (faultLabel != null) 'fault_label': faultLabel,
      if (severity != null) 'severity': severity,
      if (note != null) 'note': note,
      if (recordedAt != null) 'recorded_at': recordedAt,
    });
  }

  CheckResultsCompanion copyWith(
      {Value<int>? id,
      Value<String>? sessionId,
      Value<String>? phase,
      Value<String>? itemId,
      Value<int>? faultIndex,
      Value<String>? faultLabel,
      Value<String?>? severity,
      Value<String?>? note,
      Value<DateTime>? recordedAt}) {
    return CheckResultsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      phase: phase ?? this.phase,
      itemId: itemId ?? this.itemId,
      faultIndex: faultIndex ?? this.faultIndex,
      faultLabel: faultLabel ?? this.faultLabel,
      severity: severity ?? this.severity,
      note: note ?? this.note,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(phase.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (faultIndex.present) {
      map['fault_index'] = Variable<int>(faultIndex.value);
    }
    if (faultLabel.present) {
      map['fault_label'] = Variable<String>(faultLabel.value);
    }
    if (severity.present) {
      map['severity'] = Variable<String>(severity.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CheckResultsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('phase: $phase, ')
          ..write('itemId: $itemId, ')
          ..write('faultIndex: $faultIndex, ')
          ..write('faultLabel: $faultLabel, ')
          ..write('severity: $severity, ')
          ..write('note: $note, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }
}

class $PmcsFaultsTable extends PmcsFaults
    with TableInfo<$PmcsFaultsTable, PmcsFaultData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PmcsFaultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _phaseMeta = const VerificationMeta('phase');
  @override
  late final GeneratedColumn<String> phase = GeneratedColumn<String>(
      'phase', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _subcategoryMeta =
      const VerificationMeta('subcategory');
  @override
  late final GeneratedColumn<String> subcategory = GeneratedColumn<String>(
      'subcategory', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _conditionMeta =
      const VerificationMeta('condition');
  @override
  late final GeneratedColumn<String> condition = GeneratedColumn<String>(
      'condition', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _severityMeta =
      const VerificationMeta('severity');
  @override
  late final GeneratedColumn<String> severity = GeneratedColumn<String>(
      'severity', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _recordedAtMeta =
      const VerificationMeta('recordedAt');
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
      'recorded_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sessionId,
        itemId,
        phase,
        category,
        subcategory,
        description,
        condition,
        severity,
        note,
        recordedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pmcs_faults';
  @override
  VerificationContext validateIntegrity(Insertable<PmcsFaultData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('phase')) {
      context.handle(
          _phaseMeta, phase.isAcceptableOrUnknown(data['phase']!, _phaseMeta));
    } else if (isInserting) {
      context.missing(_phaseMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('subcategory')) {
      context.handle(
          _subcategoryMeta,
          subcategory.isAcceptableOrUnknown(
              data['subcategory']!, _subcategoryMeta));
    } else if (isInserting) {
      context.missing(_subcategoryMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('condition')) {
      context.handle(_conditionMeta,
          condition.isAcceptableOrUnknown(data['condition']!, _conditionMeta));
    } else if (isInserting) {
      context.missing(_conditionMeta);
    }
    if (data.containsKey('severity')) {
      context.handle(_severityMeta,
          severity.isAcceptableOrUnknown(data['severity']!, _severityMeta));
    } else if (isInserting) {
      context.missing(_severityMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
          _recordedAtMeta,
          recordedAt.isAcceptableOrUnknown(
              data['recorded_at']!, _recordedAtMeta));
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PmcsFaultData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PmcsFaultData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      phase: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phase'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      subcategory: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subcategory'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      condition: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}condition'])!,
      severity: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}severity'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      recordedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}recorded_at'])!,
    );
  }

  @override
  $PmcsFaultsTable createAlias(String alias) {
    return $PmcsFaultsTable(attachedDatabase, alias);
  }
}

class PmcsFaultData extends DataClass implements Insertable<PmcsFaultData> {
  final int id;
  final String sessionId;
  final String itemId;
  final String phase;
  final String category;
  final String subcategory;
  final String description;
  final String condition;
  final String severity;
  final String? note;
  final DateTime recordedAt;
  const PmcsFaultData(
      {required this.id,
      required this.sessionId,
      required this.itemId,
      required this.phase,
      required this.category,
      required this.subcategory,
      required this.description,
      required this.condition,
      required this.severity,
      this.note,
      required this.recordedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['item_id'] = Variable<String>(itemId);
    map['phase'] = Variable<String>(phase);
    map['category'] = Variable<String>(category);
    map['subcategory'] = Variable<String>(subcategory);
    map['description'] = Variable<String>(description);
    map['condition'] = Variable<String>(condition);
    map['severity'] = Variable<String>(severity);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    return map;
  }

  PmcsFaultsCompanion toCompanion(bool nullToAbsent) {
    return PmcsFaultsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      itemId: Value(itemId),
      phase: Value(phase),
      category: Value(category),
      subcategory: Value(subcategory),
      description: Value(description),
      condition: Value(condition),
      severity: Value(severity),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      recordedAt: Value(recordedAt),
    );
  }

  factory PmcsFaultData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PmcsFaultData(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      phase: serializer.fromJson<String>(json['phase']),
      category: serializer.fromJson<String>(json['category']),
      subcategory: serializer.fromJson<String>(json['subcategory']),
      description: serializer.fromJson<String>(json['description']),
      condition: serializer.fromJson<String>(json['condition']),
      severity: serializer.fromJson<String>(json['severity']),
      note: serializer.fromJson<String?>(json['note']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'itemId': serializer.toJson<String>(itemId),
      'phase': serializer.toJson<String>(phase),
      'category': serializer.toJson<String>(category),
      'subcategory': serializer.toJson<String>(subcategory),
      'description': serializer.toJson<String>(description),
      'condition': serializer.toJson<String>(condition),
      'severity': serializer.toJson<String>(severity),
      'note': serializer.toJson<String?>(note),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
    };
  }

  PmcsFaultData copyWith(
          {int? id,
          String? sessionId,
          String? itemId,
          String? phase,
          String? category,
          String? subcategory,
          String? description,
          String? condition,
          String? severity,
          Value<String?> note = const Value.absent(),
          DateTime? recordedAt}) =>
      PmcsFaultData(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        itemId: itemId ?? this.itemId,
        phase: phase ?? this.phase,
        category: category ?? this.category,
        subcategory: subcategory ?? this.subcategory,
        description: description ?? this.description,
        condition: condition ?? this.condition,
        severity: severity ?? this.severity,
        note: note.present ? note.value : this.note,
        recordedAt: recordedAt ?? this.recordedAt,
      );
  PmcsFaultData copyWithCompanion(PmcsFaultsCompanion data) {
    return PmcsFaultData(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      phase: data.phase.present ? data.phase.value : this.phase,
      category: data.category.present ? data.category.value : this.category,
      subcategory:
          data.subcategory.present ? data.subcategory.value : this.subcategory,
      description:
          data.description.present ? data.description.value : this.description,
      condition: data.condition.present ? data.condition.value : this.condition,
      severity: data.severity.present ? data.severity.value : this.severity,
      note: data.note.present ? data.note.value : this.note,
      recordedAt:
          data.recordedAt.present ? data.recordedAt.value : this.recordedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PmcsFaultData(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('itemId: $itemId, ')
          ..write('phase: $phase, ')
          ..write('category: $category, ')
          ..write('subcategory: $subcategory, ')
          ..write('description: $description, ')
          ..write('condition: $condition, ')
          ..write('severity: $severity, ')
          ..write('note: $note, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, itemId, phase, category,
      subcategory, description, condition, severity, note, recordedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PmcsFaultData &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.itemId == this.itemId &&
          other.phase == this.phase &&
          other.category == this.category &&
          other.subcategory == this.subcategory &&
          other.description == this.description &&
          other.condition == this.condition &&
          other.severity == this.severity &&
          other.note == this.note &&
          other.recordedAt == this.recordedAt);
}

class PmcsFaultsCompanion extends UpdateCompanion<PmcsFaultData> {
  final Value<int> id;
  final Value<String> sessionId;
  final Value<String> itemId;
  final Value<String> phase;
  final Value<String> category;
  final Value<String> subcategory;
  final Value<String> description;
  final Value<String> condition;
  final Value<String> severity;
  final Value<String?> note;
  final Value<DateTime> recordedAt;
  const PmcsFaultsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.phase = const Value.absent(),
    this.category = const Value.absent(),
    this.subcategory = const Value.absent(),
    this.description = const Value.absent(),
    this.condition = const Value.absent(),
    this.severity = const Value.absent(),
    this.note = const Value.absent(),
    this.recordedAt = const Value.absent(),
  });
  PmcsFaultsCompanion.insert({
    this.id = const Value.absent(),
    required String sessionId,
    required String itemId,
    required String phase,
    required String category,
    required String subcategory,
    required String description,
    required String condition,
    required String severity,
    this.note = const Value.absent(),
    required DateTime recordedAt,
  })  : sessionId = Value(sessionId),
        itemId = Value(itemId),
        phase = Value(phase),
        category = Value(category),
        subcategory = Value(subcategory),
        description = Value(description),
        condition = Value(condition),
        severity = Value(severity),
        recordedAt = Value(recordedAt);
  static Insertable<PmcsFaultData> custom({
    Expression<int>? id,
    Expression<String>? sessionId,
    Expression<String>? itemId,
    Expression<String>? phase,
    Expression<String>? category,
    Expression<String>? subcategory,
    Expression<String>? description,
    Expression<String>? condition,
    Expression<String>? severity,
    Expression<String>? note,
    Expression<DateTime>? recordedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (itemId != null) 'item_id': itemId,
      if (phase != null) 'phase': phase,
      if (category != null) 'category': category,
      if (subcategory != null) 'subcategory': subcategory,
      if (description != null) 'description': description,
      if (condition != null) 'condition': condition,
      if (severity != null) 'severity': severity,
      if (note != null) 'note': note,
      if (recordedAt != null) 'recorded_at': recordedAt,
    });
  }

  PmcsFaultsCompanion copyWith(
      {Value<int>? id,
      Value<String>? sessionId,
      Value<String>? itemId,
      Value<String>? phase,
      Value<String>? category,
      Value<String>? subcategory,
      Value<String>? description,
      Value<String>? condition,
      Value<String>? severity,
      Value<String?>? note,
      Value<DateTime>? recordedAt}) {
    return PmcsFaultsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      itemId: itemId ?? this.itemId,
      phase: phase ?? this.phase,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      description: description ?? this.description,
      condition: condition ?? this.condition,
      severity: severity ?? this.severity,
      note: note ?? this.note,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(phase.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (subcategory.present) {
      map['subcategory'] = Variable<String>(subcategory.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (condition.present) {
      map['condition'] = Variable<String>(condition.value);
    }
    if (severity.present) {
      map['severity'] = Variable<String>(severity.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PmcsFaultsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('itemId: $itemId, ')
          ..write('phase: $phase, ')
          ..write('category: $category, ')
          ..write('subcategory: $subcategory, ')
          ..write('description: $description, ')
          ..write('condition: $condition, ')
          ..write('severity: $severity, ')
          ..write('note: $note, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }
}

class $PmcsReportsTable extends PmcsReports
    with TableInfo<$PmcsReportsTable, PmcsReportData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PmcsReportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fromCallsignMeta =
      const VerificationMeta('fromCallsign');
  @override
  late final GeneratedColumn<String> fromCallsign = GeneratedColumn<String>(
      'from_callsign', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bumperNumberMeta =
      const VerificationMeta('bumperNumber');
  @override
  late final GeneratedColumn<String> bumperNumber = GeneratedColumn<String>(
      'bumper_number', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _vehicleTypeMeta =
      const VerificationMeta('vehicleType');
  @override
  late final GeneratedColumn<String> vehicleType = GeneratedColumn<String>(
      'vehicle_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operatorMeta =
      const VerificationMeta('operator');
  @override
  late final GeneratedColumn<String> operator = GeneratedColumn<String>(
      'operator', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _uicMeta = const VerificationMeta('uic');
  @override
  late final GeneratedColumn<String> uic = GeneratedColumn<String>(
      'uic', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _phasesMeta = const VerificationMeta('phases');
  @override
  late final GeneratedColumn<String> phases = GeneratedColumn<String>(
      'phases', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _faultsJsonMeta =
      const VerificationMeta('faultsJson');
  @override
  late final GeneratedColumn<String> faultsJson = GeneratedColumn<String>(
      'faults_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _signatureJsonMeta =
      const VerificationMeta('signatureJson');
  @override
  late final GeneratedColumn<String> signatureJson = GeneratedColumn<String>(
      'signature_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isOutgoingMeta =
      const VerificationMeta('isOutgoing');
  @override
  late final GeneratedColumn<bool> isOutgoing = GeneratedColumn<bool>(
      'is_outgoing', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_outgoing" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
      'is_read', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_read" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        entityId,
        fromCallsign,
        bumperNumber,
        vehicleType,
        operator,
        uic,
        phases,
        faultsJson,
        signatureJson,
        latitude,
        longitude,
        timestamp,
        isOutgoing,
        isRead
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pmcs_reports';
  @override
  VerificationContext validateIntegrity(Insertable<PmcsReportData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('from_callsign')) {
      context.handle(
          _fromCallsignMeta,
          fromCallsign.isAcceptableOrUnknown(
              data['from_callsign']!, _fromCallsignMeta));
    } else if (isInserting) {
      context.missing(_fromCallsignMeta);
    }
    if (data.containsKey('bumper_number')) {
      context.handle(
          _bumperNumberMeta,
          bumperNumber.isAcceptableOrUnknown(
              data['bumper_number']!, _bumperNumberMeta));
    } else if (isInserting) {
      context.missing(_bumperNumberMeta);
    }
    if (data.containsKey('vehicle_type')) {
      context.handle(
          _vehicleTypeMeta,
          vehicleType.isAcceptableOrUnknown(
              data['vehicle_type']!, _vehicleTypeMeta));
    } else if (isInserting) {
      context.missing(_vehicleTypeMeta);
    }
    if (data.containsKey('operator')) {
      context.handle(_operatorMeta,
          operator.isAcceptableOrUnknown(data['operator']!, _operatorMeta));
    } else if (isInserting) {
      context.missing(_operatorMeta);
    }
    if (data.containsKey('uic')) {
      context.handle(
          _uicMeta, uic.isAcceptableOrUnknown(data['uic']!, _uicMeta));
    } else if (isInserting) {
      context.missing(_uicMeta);
    }
    if (data.containsKey('phases')) {
      context.handle(_phasesMeta,
          phases.isAcceptableOrUnknown(data['phases']!, _phasesMeta));
    } else if (isInserting) {
      context.missing(_phasesMeta);
    }
    if (data.containsKey('faults_json')) {
      context.handle(
          _faultsJsonMeta,
          faultsJson.isAcceptableOrUnknown(
              data['faults_json']!, _faultsJsonMeta));
    } else if (isInserting) {
      context.missing(_faultsJsonMeta);
    }
    if (data.containsKey('signature_json')) {
      context.handle(
          _signatureJsonMeta,
          signatureJson.isAcceptableOrUnknown(
              data['signature_json']!, _signatureJsonMeta));
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('is_outgoing')) {
      context.handle(
          _isOutgoingMeta,
          isOutgoing.isAcceptableOrUnknown(
              data['is_outgoing']!, _isOutgoingMeta));
    }
    if (data.containsKey('is_read')) {
      context.handle(_isReadMeta,
          isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PmcsReportData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PmcsReportData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id'])!,
      fromCallsign: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}from_callsign'])!,
      bumperNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bumper_number'])!,
      vehicleType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}vehicle_type'])!,
      operator: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operator'])!,
      uic: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uic'])!,
      phases: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phases'])!,
      faultsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}faults_json'])!,
      signatureJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}signature_json']),
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude'])!,
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      isOutgoing: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_outgoing'])!,
      isRead: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_read'])!,
    );
  }

  @override
  $PmcsReportsTable createAlias(String alias) {
    return $PmcsReportsTable(attachedDatabase, alias);
  }
}

class PmcsReportData extends DataClass implements Insertable<PmcsReportData> {
  final int id;

  /// Shared with the Lattice entity and the mesh payload, so the same PMCS
  /// arriving on both transports lands as one report.
  final String entityId;
  final String fromCallsign;
  final String bumperNumber;
  final String vehicleType;
  final String operator;

  /// Unit Identification Code, carried from the profile.
  final String uic;

  /// Comma-joined phase wire names covered by this submission.
  final String phases;

  /// JSON list of `PmcsFault.toMap()` — the fault detail travels with the
  /// report so a receiving crew never needs the sender's session rows.
  final String faultsJson;

  /// `PmcsSignature.toMap()` as JSON — who signed it off and whether a CAC
  /// backed it up. Null on a report from a build that predates verification.
  final String? signatureJson;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final bool isOutgoing;
  final bool isRead;
  const PmcsReportData(
      {required this.id,
      required this.entityId,
      required this.fromCallsign,
      required this.bumperNumber,
      required this.vehicleType,
      required this.operator,
      required this.uic,
      required this.phases,
      required this.faultsJson,
      this.signatureJson,
      required this.latitude,
      required this.longitude,
      required this.timestamp,
      required this.isOutgoing,
      required this.isRead});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_id'] = Variable<String>(entityId);
    map['from_callsign'] = Variable<String>(fromCallsign);
    map['bumper_number'] = Variable<String>(bumperNumber);
    map['vehicle_type'] = Variable<String>(vehicleType);
    map['operator'] = Variable<String>(operator);
    map['uic'] = Variable<String>(uic);
    map['phases'] = Variable<String>(phases);
    map['faults_json'] = Variable<String>(faultsJson);
    if (!nullToAbsent || signatureJson != null) {
      map['signature_json'] = Variable<String>(signatureJson);
    }
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['is_outgoing'] = Variable<bool>(isOutgoing);
    map['is_read'] = Variable<bool>(isRead);
    return map;
  }

  PmcsReportsCompanion toCompanion(bool nullToAbsent) {
    return PmcsReportsCompanion(
      id: Value(id),
      entityId: Value(entityId),
      fromCallsign: Value(fromCallsign),
      bumperNumber: Value(bumperNumber),
      vehicleType: Value(vehicleType),
      operator: Value(operator),
      uic: Value(uic),
      phases: Value(phases),
      faultsJson: Value(faultsJson),
      signatureJson: signatureJson == null && nullToAbsent
          ? const Value.absent()
          : Value(signatureJson),
      latitude: Value(latitude),
      longitude: Value(longitude),
      timestamp: Value(timestamp),
      isOutgoing: Value(isOutgoing),
      isRead: Value(isRead),
    );
  }

  factory PmcsReportData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PmcsReportData(
      id: serializer.fromJson<int>(json['id']),
      entityId: serializer.fromJson<String>(json['entityId']),
      fromCallsign: serializer.fromJson<String>(json['fromCallsign']),
      bumperNumber: serializer.fromJson<String>(json['bumperNumber']),
      vehicleType: serializer.fromJson<String>(json['vehicleType']),
      operator: serializer.fromJson<String>(json['operator']),
      uic: serializer.fromJson<String>(json['uic']),
      phases: serializer.fromJson<String>(json['phases']),
      faultsJson: serializer.fromJson<String>(json['faultsJson']),
      signatureJson: serializer.fromJson<String?>(json['signatureJson']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      isOutgoing: serializer.fromJson<bool>(json['isOutgoing']),
      isRead: serializer.fromJson<bool>(json['isRead']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityId': serializer.toJson<String>(entityId),
      'fromCallsign': serializer.toJson<String>(fromCallsign),
      'bumperNumber': serializer.toJson<String>(bumperNumber),
      'vehicleType': serializer.toJson<String>(vehicleType),
      'operator': serializer.toJson<String>(operator),
      'uic': serializer.toJson<String>(uic),
      'phases': serializer.toJson<String>(phases),
      'faultsJson': serializer.toJson<String>(faultsJson),
      'signatureJson': serializer.toJson<String?>(signatureJson),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'isOutgoing': serializer.toJson<bool>(isOutgoing),
      'isRead': serializer.toJson<bool>(isRead),
    };
  }

  PmcsReportData copyWith(
          {int? id,
          String? entityId,
          String? fromCallsign,
          String? bumperNumber,
          String? vehicleType,
          String? operator,
          String? uic,
          String? phases,
          String? faultsJson,
          Value<String?> signatureJson = const Value.absent(),
          double? latitude,
          double? longitude,
          DateTime? timestamp,
          bool? isOutgoing,
          bool? isRead}) =>
      PmcsReportData(
        id: id ?? this.id,
        entityId: entityId ?? this.entityId,
        fromCallsign: fromCallsign ?? this.fromCallsign,
        bumperNumber: bumperNumber ?? this.bumperNumber,
        vehicleType: vehicleType ?? this.vehicleType,
        operator: operator ?? this.operator,
        uic: uic ?? this.uic,
        phases: phases ?? this.phases,
        faultsJson: faultsJson ?? this.faultsJson,
        signatureJson:
            signatureJson.present ? signatureJson.value : this.signatureJson,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        timestamp: timestamp ?? this.timestamp,
        isOutgoing: isOutgoing ?? this.isOutgoing,
        isRead: isRead ?? this.isRead,
      );
  PmcsReportData copyWithCompanion(PmcsReportsCompanion data) {
    return PmcsReportData(
      id: data.id.present ? data.id.value : this.id,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      fromCallsign: data.fromCallsign.present
          ? data.fromCallsign.value
          : this.fromCallsign,
      bumperNumber: data.bumperNumber.present
          ? data.bumperNumber.value
          : this.bumperNumber,
      vehicleType:
          data.vehicleType.present ? data.vehicleType.value : this.vehicleType,
      operator: data.operator.present ? data.operator.value : this.operator,
      uic: data.uic.present ? data.uic.value : this.uic,
      phases: data.phases.present ? data.phases.value : this.phases,
      faultsJson:
          data.faultsJson.present ? data.faultsJson.value : this.faultsJson,
      signatureJson: data.signatureJson.present
          ? data.signatureJson.value
          : this.signatureJson,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      isOutgoing:
          data.isOutgoing.present ? data.isOutgoing.value : this.isOutgoing,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PmcsReportData(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('fromCallsign: $fromCallsign, ')
          ..write('bumperNumber: $bumperNumber, ')
          ..write('vehicleType: $vehicleType, ')
          ..write('operator: $operator, ')
          ..write('uic: $uic, ')
          ..write('phases: $phases, ')
          ..write('faultsJson: $faultsJson, ')
          ..write('signatureJson: $signatureJson, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('timestamp: $timestamp, ')
          ..write('isOutgoing: $isOutgoing, ')
          ..write('isRead: $isRead')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      entityId,
      fromCallsign,
      bumperNumber,
      vehicleType,
      operator,
      uic,
      phases,
      faultsJson,
      signatureJson,
      latitude,
      longitude,
      timestamp,
      isOutgoing,
      isRead);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PmcsReportData &&
          other.id == this.id &&
          other.entityId == this.entityId &&
          other.fromCallsign == this.fromCallsign &&
          other.bumperNumber == this.bumperNumber &&
          other.vehicleType == this.vehicleType &&
          other.operator == this.operator &&
          other.uic == this.uic &&
          other.phases == this.phases &&
          other.faultsJson == this.faultsJson &&
          other.signatureJson == this.signatureJson &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.timestamp == this.timestamp &&
          other.isOutgoing == this.isOutgoing &&
          other.isRead == this.isRead);
}

class PmcsReportsCompanion extends UpdateCompanion<PmcsReportData> {
  final Value<int> id;
  final Value<String> entityId;
  final Value<String> fromCallsign;
  final Value<String> bumperNumber;
  final Value<String> vehicleType;
  final Value<String> operator;
  final Value<String> uic;
  final Value<String> phases;
  final Value<String> faultsJson;
  final Value<String?> signatureJson;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<DateTime> timestamp;
  final Value<bool> isOutgoing;
  final Value<bool> isRead;
  const PmcsReportsCompanion({
    this.id = const Value.absent(),
    this.entityId = const Value.absent(),
    this.fromCallsign = const Value.absent(),
    this.bumperNumber = const Value.absent(),
    this.vehicleType = const Value.absent(),
    this.operator = const Value.absent(),
    this.uic = const Value.absent(),
    this.phases = const Value.absent(),
    this.faultsJson = const Value.absent(),
    this.signatureJson = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.isOutgoing = const Value.absent(),
    this.isRead = const Value.absent(),
  });
  PmcsReportsCompanion.insert({
    this.id = const Value.absent(),
    required String entityId,
    required String fromCallsign,
    required String bumperNumber,
    required String vehicleType,
    required String operator,
    required String uic,
    required String phases,
    required String faultsJson,
    this.signatureJson = const Value.absent(),
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    this.isOutgoing = const Value.absent(),
    this.isRead = const Value.absent(),
  })  : entityId = Value(entityId),
        fromCallsign = Value(fromCallsign),
        bumperNumber = Value(bumperNumber),
        vehicleType = Value(vehicleType),
        operator = Value(operator),
        uic = Value(uic),
        phases = Value(phases),
        faultsJson = Value(faultsJson),
        latitude = Value(latitude),
        longitude = Value(longitude),
        timestamp = Value(timestamp);
  static Insertable<PmcsReportData> custom({
    Expression<int>? id,
    Expression<String>? entityId,
    Expression<String>? fromCallsign,
    Expression<String>? bumperNumber,
    Expression<String>? vehicleType,
    Expression<String>? operator,
    Expression<String>? uic,
    Expression<String>? phases,
    Expression<String>? faultsJson,
    Expression<String>? signatureJson,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<DateTime>? timestamp,
    Expression<bool>? isOutgoing,
    Expression<bool>? isRead,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityId != null) 'entity_id': entityId,
      if (fromCallsign != null) 'from_callsign': fromCallsign,
      if (bumperNumber != null) 'bumper_number': bumperNumber,
      if (vehicleType != null) 'vehicle_type': vehicleType,
      if (operator != null) 'operator': operator,
      if (uic != null) 'uic': uic,
      if (phases != null) 'phases': phases,
      if (faultsJson != null) 'faults_json': faultsJson,
      if (signatureJson != null) 'signature_json': signatureJson,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (timestamp != null) 'timestamp': timestamp,
      if (isOutgoing != null) 'is_outgoing': isOutgoing,
      if (isRead != null) 'is_read': isRead,
    });
  }

  PmcsReportsCompanion copyWith(
      {Value<int>? id,
      Value<String>? entityId,
      Value<String>? fromCallsign,
      Value<String>? bumperNumber,
      Value<String>? vehicleType,
      Value<String>? operator,
      Value<String>? uic,
      Value<String>? phases,
      Value<String>? faultsJson,
      Value<String?>? signatureJson,
      Value<double>? latitude,
      Value<double>? longitude,
      Value<DateTime>? timestamp,
      Value<bool>? isOutgoing,
      Value<bool>? isRead}) {
    return PmcsReportsCompanion(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      fromCallsign: fromCallsign ?? this.fromCallsign,
      bumperNumber: bumperNumber ?? this.bumperNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      operator: operator ?? this.operator,
      uic: uic ?? this.uic,
      phases: phases ?? this.phases,
      faultsJson: faultsJson ?? this.faultsJson,
      signatureJson: signatureJson ?? this.signatureJson,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (fromCallsign.present) {
      map['from_callsign'] = Variable<String>(fromCallsign.value);
    }
    if (bumperNumber.present) {
      map['bumper_number'] = Variable<String>(bumperNumber.value);
    }
    if (vehicleType.present) {
      map['vehicle_type'] = Variable<String>(vehicleType.value);
    }
    if (operator.present) {
      map['operator'] = Variable<String>(operator.value);
    }
    if (uic.present) {
      map['uic'] = Variable<String>(uic.value);
    }
    if (phases.present) {
      map['phases'] = Variable<String>(phases.value);
    }
    if (faultsJson.present) {
      map['faults_json'] = Variable<String>(faultsJson.value);
    }
    if (signatureJson.present) {
      map['signature_json'] = Variable<String>(signatureJson.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (isOutgoing.present) {
      map['is_outgoing'] = Variable<bool>(isOutgoing.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PmcsReportsCompanion(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('fromCallsign: $fromCallsign, ')
          ..write('bumperNumber: $bumperNumber, ')
          ..write('vehicleType: $vehicleType, ')
          ..write('operator: $operator, ')
          ..write('uic: $uic, ')
          ..write('phases: $phases, ')
          ..write('faultsJson: $faultsJson, ')
          ..write('signatureJson: $signatureJson, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('timestamp: $timestamp, ')
          ..write('isOutgoing: $isOutgoing, ')
          ..write('isRead: $isRead')
          ..write(')'))
        .toString();
  }
}

class $QueuedSubmissionsTable extends QueuedSubmissions
    with TableInfo<$QueuedSubmissionsTable, QueuedSubmissionData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueuedSubmissionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bumperNumberMeta =
      const VerificationMeta('bumperNumber');
  @override
  late final GeneratedColumn<String> bumperNumber = GeneratedColumn<String>(
      'bumper_number', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _vehicleTypeMeta =
      const VerificationMeta('vehicleType');
  @override
  late final GeneratedColumn<String> vehicleType = GeneratedColumn<String>(
      'vehicle_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _redXCountMeta =
      const VerificationMeta('redXCount');
  @override
  late final GeneratedColumn<int> redXCount = GeneratedColumn<int>(
      'red_x_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _faultCountMeta =
      const VerificationMeta('faultCount');
  @override
  late final GeneratedColumn<int> faultCount = GeneratedColumn<int>(
      'fault_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _transportMeta =
      const VerificationMeta('transport');
  @override
  late final GeneratedColumn<String> transport = GeneratedColumn<String>(
      'transport', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        entityId,
        bumperNumber,
        vehicleType,
        redXCount,
        faultCount,
        latitude,
        longitude,
        payload,
        transport,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queued_submissions';
  @override
  VerificationContext validateIntegrity(
      Insertable<QueuedSubmissionData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('bumper_number')) {
      context.handle(
          _bumperNumberMeta,
          bumperNumber.isAcceptableOrUnknown(
              data['bumper_number']!, _bumperNumberMeta));
    } else if (isInserting) {
      context.missing(_bumperNumberMeta);
    }
    if (data.containsKey('vehicle_type')) {
      context.handle(
          _vehicleTypeMeta,
          vehicleType.isAcceptableOrUnknown(
              data['vehicle_type']!, _vehicleTypeMeta));
    } else if (isInserting) {
      context.missing(_vehicleTypeMeta);
    }
    if (data.containsKey('red_x_count')) {
      context.handle(
          _redXCountMeta,
          redXCount.isAcceptableOrUnknown(
              data['red_x_count']!, _redXCountMeta));
    } else if (isInserting) {
      context.missing(_redXCountMeta);
    }
    if (data.containsKey('fault_count')) {
      context.handle(
          _faultCountMeta,
          faultCount.isAcceptableOrUnknown(
              data['fault_count']!, _faultCountMeta));
    } else if (isInserting) {
      context.missing(_faultCountMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('transport')) {
      context.handle(_transportMeta,
          transport.isAcceptableOrUnknown(data['transport']!, _transportMeta));
    } else if (isInserting) {
      context.missing(_transportMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QueuedSubmissionData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueuedSubmissionData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id'])!,
      bumperNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bumper_number'])!,
      vehicleType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}vehicle_type'])!,
      redXCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}red_x_count'])!,
      faultCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}fault_count'])!,
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude'])!,
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      transport: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}transport'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $QueuedSubmissionsTable createAlias(String alias) {
    return $QueuedSubmissionsTable(attachedDatabase, alias);
  }
}

class QueuedSubmissionData extends DataClass
    implements Insertable<QueuedSubmissionData> {
  final int id;
  final String entityId;
  final String bumperNumber;
  final String vehicleType;

  /// Denormalised counts so the queue screen can describe what is parked
  /// without decoding [payload].
  final int redXCount;
  final int faultCount;
  final double latitude;
  final double longitude;

  /// The already-encoded report body — a retry must send what was approved,
  /// not whatever the session has since been edited into.
  final String payload;
  final String transport;
  final DateTime createdAt;
  const QueuedSubmissionData(
      {required this.id,
      required this.entityId,
      required this.bumperNumber,
      required this.vehicleType,
      required this.redXCount,
      required this.faultCount,
      required this.latitude,
      required this.longitude,
      required this.payload,
      required this.transport,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_id'] = Variable<String>(entityId);
    map['bumper_number'] = Variable<String>(bumperNumber);
    map['vehicle_type'] = Variable<String>(vehicleType);
    map['red_x_count'] = Variable<int>(redXCount);
    map['fault_count'] = Variable<int>(faultCount);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['payload'] = Variable<String>(payload);
    map['transport'] = Variable<String>(transport);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  QueuedSubmissionsCompanion toCompanion(bool nullToAbsent) {
    return QueuedSubmissionsCompanion(
      id: Value(id),
      entityId: Value(entityId),
      bumperNumber: Value(bumperNumber),
      vehicleType: Value(vehicleType),
      redXCount: Value(redXCount),
      faultCount: Value(faultCount),
      latitude: Value(latitude),
      longitude: Value(longitude),
      payload: Value(payload),
      transport: Value(transport),
      createdAt: Value(createdAt),
    );
  }

  factory QueuedSubmissionData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueuedSubmissionData(
      id: serializer.fromJson<int>(json['id']),
      entityId: serializer.fromJson<String>(json['entityId']),
      bumperNumber: serializer.fromJson<String>(json['bumperNumber']),
      vehicleType: serializer.fromJson<String>(json['vehicleType']),
      redXCount: serializer.fromJson<int>(json['redXCount']),
      faultCount: serializer.fromJson<int>(json['faultCount']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      payload: serializer.fromJson<String>(json['payload']),
      transport: serializer.fromJson<String>(json['transport']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityId': serializer.toJson<String>(entityId),
      'bumperNumber': serializer.toJson<String>(bumperNumber),
      'vehicleType': serializer.toJson<String>(vehicleType),
      'redXCount': serializer.toJson<int>(redXCount),
      'faultCount': serializer.toJson<int>(faultCount),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'payload': serializer.toJson<String>(payload),
      'transport': serializer.toJson<String>(transport),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  QueuedSubmissionData copyWith(
          {int? id,
          String? entityId,
          String? bumperNumber,
          String? vehicleType,
          int? redXCount,
          int? faultCount,
          double? latitude,
          double? longitude,
          String? payload,
          String? transport,
          DateTime? createdAt}) =>
      QueuedSubmissionData(
        id: id ?? this.id,
        entityId: entityId ?? this.entityId,
        bumperNumber: bumperNumber ?? this.bumperNumber,
        vehicleType: vehicleType ?? this.vehicleType,
        redXCount: redXCount ?? this.redXCount,
        faultCount: faultCount ?? this.faultCount,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        payload: payload ?? this.payload,
        transport: transport ?? this.transport,
        createdAt: createdAt ?? this.createdAt,
      );
  QueuedSubmissionData copyWithCompanion(QueuedSubmissionsCompanion data) {
    return QueuedSubmissionData(
      id: data.id.present ? data.id.value : this.id,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      bumperNumber: data.bumperNumber.present
          ? data.bumperNumber.value
          : this.bumperNumber,
      vehicleType:
          data.vehicleType.present ? data.vehicleType.value : this.vehicleType,
      redXCount: data.redXCount.present ? data.redXCount.value : this.redXCount,
      faultCount:
          data.faultCount.present ? data.faultCount.value : this.faultCount,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      payload: data.payload.present ? data.payload.value : this.payload,
      transport: data.transport.present ? data.transport.value : this.transport,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueuedSubmissionData(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('bumperNumber: $bumperNumber, ')
          ..write('vehicleType: $vehicleType, ')
          ..write('redXCount: $redXCount, ')
          ..write('faultCount: $faultCount, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('payload: $payload, ')
          ..write('transport: $transport, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      entityId,
      bumperNumber,
      vehicleType,
      redXCount,
      faultCount,
      latitude,
      longitude,
      payload,
      transport,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueuedSubmissionData &&
          other.id == this.id &&
          other.entityId == this.entityId &&
          other.bumperNumber == this.bumperNumber &&
          other.vehicleType == this.vehicleType &&
          other.redXCount == this.redXCount &&
          other.faultCount == this.faultCount &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.payload == this.payload &&
          other.transport == this.transport &&
          other.createdAt == this.createdAt);
}

class QueuedSubmissionsCompanion extends UpdateCompanion<QueuedSubmissionData> {
  final Value<int> id;
  final Value<String> entityId;
  final Value<String> bumperNumber;
  final Value<String> vehicleType;
  final Value<int> redXCount;
  final Value<int> faultCount;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<String> payload;
  final Value<String> transport;
  final Value<DateTime> createdAt;
  const QueuedSubmissionsCompanion({
    this.id = const Value.absent(),
    this.entityId = const Value.absent(),
    this.bumperNumber = const Value.absent(),
    this.vehicleType = const Value.absent(),
    this.redXCount = const Value.absent(),
    this.faultCount = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.payload = const Value.absent(),
    this.transport = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  QueuedSubmissionsCompanion.insert({
    this.id = const Value.absent(),
    required String entityId,
    required String bumperNumber,
    required String vehicleType,
    required int redXCount,
    required int faultCount,
    required double latitude,
    required double longitude,
    required String payload,
    required String transport,
    required DateTime createdAt,
  })  : entityId = Value(entityId),
        bumperNumber = Value(bumperNumber),
        vehicleType = Value(vehicleType),
        redXCount = Value(redXCount),
        faultCount = Value(faultCount),
        latitude = Value(latitude),
        longitude = Value(longitude),
        payload = Value(payload),
        transport = Value(transport),
        createdAt = Value(createdAt);
  static Insertable<QueuedSubmissionData> custom({
    Expression<int>? id,
    Expression<String>? entityId,
    Expression<String>? bumperNumber,
    Expression<String>? vehicleType,
    Expression<int>? redXCount,
    Expression<int>? faultCount,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? payload,
    Expression<String>? transport,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityId != null) 'entity_id': entityId,
      if (bumperNumber != null) 'bumper_number': bumperNumber,
      if (vehicleType != null) 'vehicle_type': vehicleType,
      if (redXCount != null) 'red_x_count': redXCount,
      if (faultCount != null) 'fault_count': faultCount,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (payload != null) 'payload': payload,
      if (transport != null) 'transport': transport,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  QueuedSubmissionsCompanion copyWith(
      {Value<int>? id,
      Value<String>? entityId,
      Value<String>? bumperNumber,
      Value<String>? vehicleType,
      Value<int>? redXCount,
      Value<int>? faultCount,
      Value<double>? latitude,
      Value<double>? longitude,
      Value<String>? payload,
      Value<String>? transport,
      Value<DateTime>? createdAt}) {
    return QueuedSubmissionsCompanion(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      bumperNumber: bumperNumber ?? this.bumperNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      redXCount: redXCount ?? this.redXCount,
      faultCount: faultCount ?? this.faultCount,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      payload: payload ?? this.payload,
      transport: transport ?? this.transport,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (bumperNumber.present) {
      map['bumper_number'] = Variable<String>(bumperNumber.value);
    }
    if (vehicleType.present) {
      map['vehicle_type'] = Variable<String>(vehicleType.value);
    }
    if (redXCount.present) {
      map['red_x_count'] = Variable<int>(redXCount.value);
    }
    if (faultCount.present) {
      map['fault_count'] = Variable<int>(faultCount.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (transport.present) {
      map['transport'] = Variable<String>(transport.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueuedSubmissionsCompanion(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('bumperNumber: $bumperNumber, ')
          ..write('vehicleType: $vehicleType, ')
          ..write('redXCount: $redXCount, ')
          ..write('faultCount: $faultCount, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('payload: $payload, ')
          ..write('transport: $transport, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $PmcsSessionsTable pmcsSessions = $PmcsSessionsTable(this);
  late final $CheckResultsTable checkResults = $CheckResultsTable(this);
  late final $PmcsFaultsTable pmcsFaults = $PmcsFaultsTable(this);
  late final $PmcsReportsTable pmcsReports = $PmcsReportsTable(this);
  late final $QueuedSubmissionsTable queuedSubmissions =
      $QueuedSubmissionsTable(this);
  late final ProfileDao profileDao = ProfileDao(this as AppDatabase);
  late final SessionsDao sessionsDao = SessionsDao(this as AppDatabase);
  late final CheckResultsDao checkResultsDao =
      CheckResultsDao(this as AppDatabase);
  late final PmcsFaultsDao pmcsFaultsDao = PmcsFaultsDao(this as AppDatabase);
  late final PmcsReportsDao pmcsReportsDao =
      PmcsReportsDao(this as AppDatabase);
  late final QueuedSubmissionsDao queuedSubmissionsDao =
      QueuedSubmissionsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        profiles,
        pmcsSessions,
        checkResults,
        pmcsFaults,
        pmcsReports,
        queuedSubmissions
      ];
}

typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  Value<int> id,
  required String uic,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<int> id,
  Value<String> uic,
});

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uic => $composableBuilder(
      column: $table.uic, builder: (column) => ColumnFilters(column));
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uic => $composableBuilder(
      column: $table.uic, builder: (column) => ColumnOrderings(column));
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uic =>
      $composableBuilder(column: $table.uic, builder: (column) => column);
}

class $$ProfilesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProfilesTable,
    ProfileData,
    $$ProfilesTableFilterComposer,
    $$ProfilesTableOrderingComposer,
    $$ProfilesTableAnnotationComposer,
    $$ProfilesTableCreateCompanionBuilder,
    $$ProfilesTableUpdateCompanionBuilder,
    (ProfileData, BaseReferences<_$AppDatabase, $ProfilesTable, ProfileData>),
    ProfileData,
    PrefetchHooks Function()> {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> uic = const Value.absent(),
          }) =>
              ProfilesCompanion(
            id: id,
            uic: uic,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String uic,
          }) =>
              ProfilesCompanion.insert(
            id: id,
            uic: uic,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ProfilesTable, ProfileData>(table),
                    BaseReferences<_$AppDatabase, $ProfilesTable, ProfileData>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProfilesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProfilesTable,
    ProfileData,
    $$ProfilesTableFilterComposer,
    $$ProfilesTableOrderingComposer,
    $$ProfilesTableAnnotationComposer,
    $$ProfilesTableCreateCompanionBuilder,
    $$ProfilesTableUpdateCompanionBuilder,
    (ProfileData, BaseReferences<_$AppDatabase, $ProfilesTable, ProfileData>),
    ProfileData,
    PrefetchHooks Function()>;
typedef $$PmcsSessionsTableCreateCompanionBuilder = PmcsSessionsCompanion
    Function({
  Value<int> id,
  required String sessionId,
  required String bumperNumber,
  required String vehicleType,
  required String operator,
  required String uic,
  required DateTime startedAt,
  Value<DateTime?> submittedAt,
  Value<String> completedPhases,
  Value<String> status,
  Value<String?> signatureJson,
  Value<double?> latitude,
  Value<double?> longitude,
});
typedef $$PmcsSessionsTableUpdateCompanionBuilder = PmcsSessionsCompanion
    Function({
  Value<int> id,
  Value<String> sessionId,
  Value<String> bumperNumber,
  Value<String> vehicleType,
  Value<String> operator,
  Value<String> uic,
  Value<DateTime> startedAt,
  Value<DateTime?> submittedAt,
  Value<String> completedPhases,
  Value<String> status,
  Value<String?> signatureJson,
  Value<double?> latitude,
  Value<double?> longitude,
});

class $$PmcsSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $PmcsSessionsTable> {
  $$PmcsSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bumperNumber => $composableBuilder(
      column: $table.bumperNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get vehicleType => $composableBuilder(
      column: $table.vehicleType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operator => $composableBuilder(
      column: $table.operator, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uic => $composableBuilder(
      column: $table.uic, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get submittedAt => $composableBuilder(
      column: $table.submittedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get completedPhases => $composableBuilder(
      column: $table.completedPhases,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get signatureJson => $composableBuilder(
      column: $table.signatureJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));
}

class $$PmcsSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PmcsSessionsTable> {
  $$PmcsSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bumperNumber => $composableBuilder(
      column: $table.bumperNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get vehicleType => $composableBuilder(
      column: $table.vehicleType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operator => $composableBuilder(
      column: $table.operator, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uic => $composableBuilder(
      column: $table.uic, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get submittedAt => $composableBuilder(
      column: $table.submittedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get completedPhases => $composableBuilder(
      column: $table.completedPhases,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get signatureJson => $composableBuilder(
      column: $table.signatureJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));
}

class $$PmcsSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PmcsSessionsTable> {
  $$PmcsSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get bumperNumber => $composableBuilder(
      column: $table.bumperNumber, builder: (column) => column);

  GeneratedColumn<String> get vehicleType => $composableBuilder(
      column: $table.vehicleType, builder: (column) => column);

  GeneratedColumn<String> get operator =>
      $composableBuilder(column: $table.operator, builder: (column) => column);

  GeneratedColumn<String> get uic =>
      $composableBuilder(column: $table.uic, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get submittedAt => $composableBuilder(
      column: $table.submittedAt, builder: (column) => column);

  GeneratedColumn<String> get completedPhases => $composableBuilder(
      column: $table.completedPhases, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get signatureJson => $composableBuilder(
      column: $table.signatureJson, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);
}

class $$PmcsSessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PmcsSessionsTable,
    PmcsSessionData,
    $$PmcsSessionsTableFilterComposer,
    $$PmcsSessionsTableOrderingComposer,
    $$PmcsSessionsTableAnnotationComposer,
    $$PmcsSessionsTableCreateCompanionBuilder,
    $$PmcsSessionsTableUpdateCompanionBuilder,
    (
      PmcsSessionData,
      BaseReferences<_$AppDatabase, $PmcsSessionsTable, PmcsSessionData>
    ),
    PmcsSessionData,
    PrefetchHooks Function()> {
  $$PmcsSessionsTableTableManager(_$AppDatabase db, $PmcsSessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PmcsSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PmcsSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PmcsSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<String> bumperNumber = const Value.absent(),
            Value<String> vehicleType = const Value.absent(),
            Value<String> operator = const Value.absent(),
            Value<String> uic = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<DateTime?> submittedAt = const Value.absent(),
            Value<String> completedPhases = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> signatureJson = const Value.absent(),
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
          }) =>
              PmcsSessionsCompanion(
            id: id,
            sessionId: sessionId,
            bumperNumber: bumperNumber,
            vehicleType: vehicleType,
            operator: operator,
            uic: uic,
            startedAt: startedAt,
            submittedAt: submittedAt,
            completedPhases: completedPhases,
            status: status,
            signatureJson: signatureJson,
            latitude: latitude,
            longitude: longitude,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String sessionId,
            required String bumperNumber,
            required String vehicleType,
            required String operator,
            required String uic,
            required DateTime startedAt,
            Value<DateTime?> submittedAt = const Value.absent(),
            Value<String> completedPhases = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> signatureJson = const Value.absent(),
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
          }) =>
              PmcsSessionsCompanion.insert(
            id: id,
            sessionId: sessionId,
            bumperNumber: bumperNumber,
            vehicleType: vehicleType,
            operator: operator,
            uic: uic,
            startedAt: startedAt,
            submittedAt: submittedAt,
            completedPhases: completedPhases,
            status: status,
            signatureJson: signatureJson,
            latitude: latitude,
            longitude: longitude,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PmcsSessionsTable, PmcsSessionData>(table),
                    BaseReferences<_$AppDatabase, $PmcsSessionsTable,
                        PmcsSessionData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PmcsSessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PmcsSessionsTable,
    PmcsSessionData,
    $$PmcsSessionsTableFilterComposer,
    $$PmcsSessionsTableOrderingComposer,
    $$PmcsSessionsTableAnnotationComposer,
    $$PmcsSessionsTableCreateCompanionBuilder,
    $$PmcsSessionsTableUpdateCompanionBuilder,
    (
      PmcsSessionData,
      BaseReferences<_$AppDatabase, $PmcsSessionsTable, PmcsSessionData>
    ),
    PmcsSessionData,
    PrefetchHooks Function()>;
typedef $$CheckResultsTableCreateCompanionBuilder = CheckResultsCompanion
    Function({
  Value<int> id,
  required String sessionId,
  required String phase,
  required String itemId,
  required int faultIndex,
  required String faultLabel,
  Value<String?> severity,
  Value<String?> note,
  required DateTime recordedAt,
});
typedef $$CheckResultsTableUpdateCompanionBuilder = CheckResultsCompanion
    Function({
  Value<int> id,
  Value<String> sessionId,
  Value<String> phase,
  Value<String> itemId,
  Value<int> faultIndex,
  Value<String> faultLabel,
  Value<String?> severity,
  Value<String?> note,
  Value<DateTime> recordedAt,
});

class $$CheckResultsTableFilterComposer
    extends Composer<_$AppDatabase, $CheckResultsTable> {
  $$CheckResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phase => $composableBuilder(
      column: $table.phase, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get faultIndex => $composableBuilder(
      column: $table.faultIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get faultLabel => $composableBuilder(
      column: $table.faultLabel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get severity => $composableBuilder(
      column: $table.severity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnFilters(column));
}

class $$CheckResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $CheckResultsTable> {
  $$CheckResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phase => $composableBuilder(
      column: $table.phase, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get faultIndex => $composableBuilder(
      column: $table.faultIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get faultLabel => $composableBuilder(
      column: $table.faultLabel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get severity => $composableBuilder(
      column: $table.severity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnOrderings(column));
}

class $$CheckResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CheckResultsTable> {
  $$CheckResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get faultIndex => $composableBuilder(
      column: $table.faultIndex, builder: (column) => column);

  GeneratedColumn<String> get faultLabel => $composableBuilder(
      column: $table.faultLabel, builder: (column) => column);

  GeneratedColumn<String> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => column);
}

class $$CheckResultsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CheckResultsTable,
    CheckResultData,
    $$CheckResultsTableFilterComposer,
    $$CheckResultsTableOrderingComposer,
    $$CheckResultsTableAnnotationComposer,
    $$CheckResultsTableCreateCompanionBuilder,
    $$CheckResultsTableUpdateCompanionBuilder,
    (
      CheckResultData,
      BaseReferences<_$AppDatabase, $CheckResultsTable, CheckResultData>
    ),
    CheckResultData,
    PrefetchHooks Function()> {
  $$CheckResultsTableTableManager(_$AppDatabase db, $CheckResultsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CheckResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CheckResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CheckResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<String> phase = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<int> faultIndex = const Value.absent(),
            Value<String> faultLabel = const Value.absent(),
            Value<String?> severity = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<DateTime> recordedAt = const Value.absent(),
          }) =>
              CheckResultsCompanion(
            id: id,
            sessionId: sessionId,
            phase: phase,
            itemId: itemId,
            faultIndex: faultIndex,
            faultLabel: faultLabel,
            severity: severity,
            note: note,
            recordedAt: recordedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String sessionId,
            required String phase,
            required String itemId,
            required int faultIndex,
            required String faultLabel,
            Value<String?> severity = const Value.absent(),
            Value<String?> note = const Value.absent(),
            required DateTime recordedAt,
          }) =>
              CheckResultsCompanion.insert(
            id: id,
            sessionId: sessionId,
            phase: phase,
            itemId: itemId,
            faultIndex: faultIndex,
            faultLabel: faultLabel,
            severity: severity,
            note: note,
            recordedAt: recordedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CheckResultsTable, CheckResultData>(table),
                    BaseReferences<_$AppDatabase, $CheckResultsTable,
                        CheckResultData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CheckResultsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CheckResultsTable,
    CheckResultData,
    $$CheckResultsTableFilterComposer,
    $$CheckResultsTableOrderingComposer,
    $$CheckResultsTableAnnotationComposer,
    $$CheckResultsTableCreateCompanionBuilder,
    $$CheckResultsTableUpdateCompanionBuilder,
    (
      CheckResultData,
      BaseReferences<_$AppDatabase, $CheckResultsTable, CheckResultData>
    ),
    CheckResultData,
    PrefetchHooks Function()>;
typedef $$PmcsFaultsTableCreateCompanionBuilder = PmcsFaultsCompanion Function({
  Value<int> id,
  required String sessionId,
  required String itemId,
  required String phase,
  required String category,
  required String subcategory,
  required String description,
  required String condition,
  required String severity,
  Value<String?> note,
  required DateTime recordedAt,
});
typedef $$PmcsFaultsTableUpdateCompanionBuilder = PmcsFaultsCompanion Function({
  Value<int> id,
  Value<String> sessionId,
  Value<String> itemId,
  Value<String> phase,
  Value<String> category,
  Value<String> subcategory,
  Value<String> description,
  Value<String> condition,
  Value<String> severity,
  Value<String?> note,
  Value<DateTime> recordedAt,
});

class $$PmcsFaultsTableFilterComposer
    extends Composer<_$AppDatabase, $PmcsFaultsTable> {
  $$PmcsFaultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phase => $composableBuilder(
      column: $table.phase, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subcategory => $composableBuilder(
      column: $table.subcategory, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get condition => $composableBuilder(
      column: $table.condition, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get severity => $composableBuilder(
      column: $table.severity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnFilters(column));
}

class $$PmcsFaultsTableOrderingComposer
    extends Composer<_$AppDatabase, $PmcsFaultsTable> {
  $$PmcsFaultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phase => $composableBuilder(
      column: $table.phase, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subcategory => $composableBuilder(
      column: $table.subcategory, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get condition => $composableBuilder(
      column: $table.condition, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get severity => $composableBuilder(
      column: $table.severity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnOrderings(column));
}

class $$PmcsFaultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PmcsFaultsTable> {
  $$PmcsFaultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get subcategory => $composableBuilder(
      column: $table.subcategory, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get condition =>
      $composableBuilder(column: $table.condition, builder: (column) => column);

  GeneratedColumn<String> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => column);
}

class $$PmcsFaultsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PmcsFaultsTable,
    PmcsFaultData,
    $$PmcsFaultsTableFilterComposer,
    $$PmcsFaultsTableOrderingComposer,
    $$PmcsFaultsTableAnnotationComposer,
    $$PmcsFaultsTableCreateCompanionBuilder,
    $$PmcsFaultsTableUpdateCompanionBuilder,
    (
      PmcsFaultData,
      BaseReferences<_$AppDatabase, $PmcsFaultsTable, PmcsFaultData>
    ),
    PmcsFaultData,
    PrefetchHooks Function()> {
  $$PmcsFaultsTableTableManager(_$AppDatabase db, $PmcsFaultsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PmcsFaultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PmcsFaultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PmcsFaultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<String> phase = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> subcategory = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<String> condition = const Value.absent(),
            Value<String> severity = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<DateTime> recordedAt = const Value.absent(),
          }) =>
              PmcsFaultsCompanion(
            id: id,
            sessionId: sessionId,
            itemId: itemId,
            phase: phase,
            category: category,
            subcategory: subcategory,
            description: description,
            condition: condition,
            severity: severity,
            note: note,
            recordedAt: recordedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String sessionId,
            required String itemId,
            required String phase,
            required String category,
            required String subcategory,
            required String description,
            required String condition,
            required String severity,
            Value<String?> note = const Value.absent(),
            required DateTime recordedAt,
          }) =>
              PmcsFaultsCompanion.insert(
            id: id,
            sessionId: sessionId,
            itemId: itemId,
            phase: phase,
            category: category,
            subcategory: subcategory,
            description: description,
            condition: condition,
            severity: severity,
            note: note,
            recordedAt: recordedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PmcsFaultsTable, PmcsFaultData>(table),
                    BaseReferences<_$AppDatabase, $PmcsFaultsTable,
                        PmcsFaultData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PmcsFaultsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PmcsFaultsTable,
    PmcsFaultData,
    $$PmcsFaultsTableFilterComposer,
    $$PmcsFaultsTableOrderingComposer,
    $$PmcsFaultsTableAnnotationComposer,
    $$PmcsFaultsTableCreateCompanionBuilder,
    $$PmcsFaultsTableUpdateCompanionBuilder,
    (
      PmcsFaultData,
      BaseReferences<_$AppDatabase, $PmcsFaultsTable, PmcsFaultData>
    ),
    PmcsFaultData,
    PrefetchHooks Function()>;
typedef $$PmcsReportsTableCreateCompanionBuilder = PmcsReportsCompanion
    Function({
  Value<int> id,
  required String entityId,
  required String fromCallsign,
  required String bumperNumber,
  required String vehicleType,
  required String operator,
  required String uic,
  required String phases,
  required String faultsJson,
  Value<String?> signatureJson,
  required double latitude,
  required double longitude,
  required DateTime timestamp,
  Value<bool> isOutgoing,
  Value<bool> isRead,
});
typedef $$PmcsReportsTableUpdateCompanionBuilder = PmcsReportsCompanion
    Function({
  Value<int> id,
  Value<String> entityId,
  Value<String> fromCallsign,
  Value<String> bumperNumber,
  Value<String> vehicleType,
  Value<String> operator,
  Value<String> uic,
  Value<String> phases,
  Value<String> faultsJson,
  Value<String?> signatureJson,
  Value<double> latitude,
  Value<double> longitude,
  Value<DateTime> timestamp,
  Value<bool> isOutgoing,
  Value<bool> isRead,
});

class $$PmcsReportsTableFilterComposer
    extends Composer<_$AppDatabase, $PmcsReportsTable> {
  $$PmcsReportsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fromCallsign => $composableBuilder(
      column: $table.fromCallsign, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bumperNumber => $composableBuilder(
      column: $table.bumperNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get vehicleType => $composableBuilder(
      column: $table.vehicleType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operator => $composableBuilder(
      column: $table.operator, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uic => $composableBuilder(
      column: $table.uic, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phases => $composableBuilder(
      column: $table.phases, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get faultsJson => $composableBuilder(
      column: $table.faultsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get signatureJson => $composableBuilder(
      column: $table.signatureJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isOutgoing => $composableBuilder(
      column: $table.isOutgoing, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isRead => $composableBuilder(
      column: $table.isRead, builder: (column) => ColumnFilters(column));
}

class $$PmcsReportsTableOrderingComposer
    extends Composer<_$AppDatabase, $PmcsReportsTable> {
  $$PmcsReportsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fromCallsign => $composableBuilder(
      column: $table.fromCallsign,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bumperNumber => $composableBuilder(
      column: $table.bumperNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get vehicleType => $composableBuilder(
      column: $table.vehicleType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operator => $composableBuilder(
      column: $table.operator, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uic => $composableBuilder(
      column: $table.uic, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phases => $composableBuilder(
      column: $table.phases, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get faultsJson => $composableBuilder(
      column: $table.faultsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get signatureJson => $composableBuilder(
      column: $table.signatureJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isOutgoing => $composableBuilder(
      column: $table.isOutgoing, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isRead => $composableBuilder(
      column: $table.isRead, builder: (column) => ColumnOrderings(column));
}

class $$PmcsReportsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PmcsReportsTable> {
  $$PmcsReportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get fromCallsign => $composableBuilder(
      column: $table.fromCallsign, builder: (column) => column);

  GeneratedColumn<String> get bumperNumber => $composableBuilder(
      column: $table.bumperNumber, builder: (column) => column);

  GeneratedColumn<String> get vehicleType => $composableBuilder(
      column: $table.vehicleType, builder: (column) => column);

  GeneratedColumn<String> get operator =>
      $composableBuilder(column: $table.operator, builder: (column) => column);

  GeneratedColumn<String> get uic =>
      $composableBuilder(column: $table.uic, builder: (column) => column);

  GeneratedColumn<String> get phases =>
      $composableBuilder(column: $table.phases, builder: (column) => column);

  GeneratedColumn<String> get faultsJson => $composableBuilder(
      column: $table.faultsJson, builder: (column) => column);

  GeneratedColumn<String> get signatureJson => $composableBuilder(
      column: $table.signatureJson, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<bool> get isOutgoing => $composableBuilder(
      column: $table.isOutgoing, builder: (column) => column);

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);
}

class $$PmcsReportsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PmcsReportsTable,
    PmcsReportData,
    $$PmcsReportsTableFilterComposer,
    $$PmcsReportsTableOrderingComposer,
    $$PmcsReportsTableAnnotationComposer,
    $$PmcsReportsTableCreateCompanionBuilder,
    $$PmcsReportsTableUpdateCompanionBuilder,
    (
      PmcsReportData,
      BaseReferences<_$AppDatabase, $PmcsReportsTable, PmcsReportData>
    ),
    PmcsReportData,
    PrefetchHooks Function()> {
  $$PmcsReportsTableTableManager(_$AppDatabase db, $PmcsReportsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PmcsReportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PmcsReportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PmcsReportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> entityId = const Value.absent(),
            Value<String> fromCallsign = const Value.absent(),
            Value<String> bumperNumber = const Value.absent(),
            Value<String> vehicleType = const Value.absent(),
            Value<String> operator = const Value.absent(),
            Value<String> uic = const Value.absent(),
            Value<String> phases = const Value.absent(),
            Value<String> faultsJson = const Value.absent(),
            Value<String?> signatureJson = const Value.absent(),
            Value<double> latitude = const Value.absent(),
            Value<double> longitude = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<bool> isOutgoing = const Value.absent(),
            Value<bool> isRead = const Value.absent(),
          }) =>
              PmcsReportsCompanion(
            id: id,
            entityId: entityId,
            fromCallsign: fromCallsign,
            bumperNumber: bumperNumber,
            vehicleType: vehicleType,
            operator: operator,
            uic: uic,
            phases: phases,
            faultsJson: faultsJson,
            signatureJson: signatureJson,
            latitude: latitude,
            longitude: longitude,
            timestamp: timestamp,
            isOutgoing: isOutgoing,
            isRead: isRead,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String entityId,
            required String fromCallsign,
            required String bumperNumber,
            required String vehicleType,
            required String operator,
            required String uic,
            required String phases,
            required String faultsJson,
            Value<String?> signatureJson = const Value.absent(),
            required double latitude,
            required double longitude,
            required DateTime timestamp,
            Value<bool> isOutgoing = const Value.absent(),
            Value<bool> isRead = const Value.absent(),
          }) =>
              PmcsReportsCompanion.insert(
            id: id,
            entityId: entityId,
            fromCallsign: fromCallsign,
            bumperNumber: bumperNumber,
            vehicleType: vehicleType,
            operator: operator,
            uic: uic,
            phases: phases,
            faultsJson: faultsJson,
            signatureJson: signatureJson,
            latitude: latitude,
            longitude: longitude,
            timestamp: timestamp,
            isOutgoing: isOutgoing,
            isRead: isRead,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PmcsReportsTable, PmcsReportData>(table),
                    BaseReferences<_$AppDatabase, $PmcsReportsTable,
                        PmcsReportData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PmcsReportsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PmcsReportsTable,
    PmcsReportData,
    $$PmcsReportsTableFilterComposer,
    $$PmcsReportsTableOrderingComposer,
    $$PmcsReportsTableAnnotationComposer,
    $$PmcsReportsTableCreateCompanionBuilder,
    $$PmcsReportsTableUpdateCompanionBuilder,
    (
      PmcsReportData,
      BaseReferences<_$AppDatabase, $PmcsReportsTable, PmcsReportData>
    ),
    PmcsReportData,
    PrefetchHooks Function()>;
typedef $$QueuedSubmissionsTableCreateCompanionBuilder
    = QueuedSubmissionsCompanion Function({
  Value<int> id,
  required String entityId,
  required String bumperNumber,
  required String vehicleType,
  required int redXCount,
  required int faultCount,
  required double latitude,
  required double longitude,
  required String payload,
  required String transport,
  required DateTime createdAt,
});
typedef $$QueuedSubmissionsTableUpdateCompanionBuilder
    = QueuedSubmissionsCompanion Function({
  Value<int> id,
  Value<String> entityId,
  Value<String> bumperNumber,
  Value<String> vehicleType,
  Value<int> redXCount,
  Value<int> faultCount,
  Value<double> latitude,
  Value<double> longitude,
  Value<String> payload,
  Value<String> transport,
  Value<DateTime> createdAt,
});

class $$QueuedSubmissionsTableFilterComposer
    extends Composer<_$AppDatabase, $QueuedSubmissionsTable> {
  $$QueuedSubmissionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bumperNumber => $composableBuilder(
      column: $table.bumperNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get vehicleType => $composableBuilder(
      column: $table.vehicleType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get redXCount => $composableBuilder(
      column: $table.redXCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get faultCount => $composableBuilder(
      column: $table.faultCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get transport => $composableBuilder(
      column: $table.transport, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$QueuedSubmissionsTableOrderingComposer
    extends Composer<_$AppDatabase, $QueuedSubmissionsTable> {
  $$QueuedSubmissionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bumperNumber => $composableBuilder(
      column: $table.bumperNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get vehicleType => $composableBuilder(
      column: $table.vehicleType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get redXCount => $composableBuilder(
      column: $table.redXCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get faultCount => $composableBuilder(
      column: $table.faultCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get transport => $composableBuilder(
      column: $table.transport, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$QueuedSubmissionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QueuedSubmissionsTable> {
  $$QueuedSubmissionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get bumperNumber => $composableBuilder(
      column: $table.bumperNumber, builder: (column) => column);

  GeneratedColumn<String> get vehicleType => $composableBuilder(
      column: $table.vehicleType, builder: (column) => column);

  GeneratedColumn<int> get redXCount =>
      $composableBuilder(column: $table.redXCount, builder: (column) => column);

  GeneratedColumn<int> get faultCount => $composableBuilder(
      column: $table.faultCount, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get transport =>
      $composableBuilder(column: $table.transport, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$QueuedSubmissionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $QueuedSubmissionsTable,
    QueuedSubmissionData,
    $$QueuedSubmissionsTableFilterComposer,
    $$QueuedSubmissionsTableOrderingComposer,
    $$QueuedSubmissionsTableAnnotationComposer,
    $$QueuedSubmissionsTableCreateCompanionBuilder,
    $$QueuedSubmissionsTableUpdateCompanionBuilder,
    (
      QueuedSubmissionData,
      BaseReferences<_$AppDatabase, $QueuedSubmissionsTable,
          QueuedSubmissionData>
    ),
    QueuedSubmissionData,
    PrefetchHooks Function()> {
  $$QueuedSubmissionsTableTableManager(
      _$AppDatabase db, $QueuedSubmissionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueuedSubmissionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueuedSubmissionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueuedSubmissionsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> entityId = const Value.absent(),
            Value<String> bumperNumber = const Value.absent(),
            Value<String> vehicleType = const Value.absent(),
            Value<int> redXCount = const Value.absent(),
            Value<int> faultCount = const Value.absent(),
            Value<double> latitude = const Value.absent(),
            Value<double> longitude = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<String> transport = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              QueuedSubmissionsCompanion(
            id: id,
            entityId: entityId,
            bumperNumber: bumperNumber,
            vehicleType: vehicleType,
            redXCount: redXCount,
            faultCount: faultCount,
            latitude: latitude,
            longitude: longitude,
            payload: payload,
            transport: transport,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String entityId,
            required String bumperNumber,
            required String vehicleType,
            required int redXCount,
            required int faultCount,
            required double latitude,
            required double longitude,
            required String payload,
            required String transport,
            required DateTime createdAt,
          }) =>
              QueuedSubmissionsCompanion.insert(
            id: id,
            entityId: entityId,
            bumperNumber: bumperNumber,
            vehicleType: vehicleType,
            redXCount: redXCount,
            faultCount: faultCount,
            latitude: latitude,
            longitude: longitude,
            payload: payload,
            transport: transport,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$QueuedSubmissionsTable, QueuedSubmissionData>(
                        table),
                    BaseReferences<_$AppDatabase, $QueuedSubmissionsTable,
                        QueuedSubmissionData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$QueuedSubmissionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $QueuedSubmissionsTable,
    QueuedSubmissionData,
    $$QueuedSubmissionsTableFilterComposer,
    $$QueuedSubmissionsTableOrderingComposer,
    $$QueuedSubmissionsTableAnnotationComposer,
    $$QueuedSubmissionsTableCreateCompanionBuilder,
    $$QueuedSubmissionsTableUpdateCompanionBuilder,
    (
      QueuedSubmissionData,
      BaseReferences<_$AppDatabase, $QueuedSubmissionsTable,
          QueuedSubmissionData>
    ),
    QueuedSubmissionData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$PmcsSessionsTableTableManager get pmcsSessions =>
      $$PmcsSessionsTableTableManager(_db, _db.pmcsSessions);
  $$CheckResultsTableTableManager get checkResults =>
      $$CheckResultsTableTableManager(_db, _db.checkResults);
  $$PmcsFaultsTableTableManager get pmcsFaults =>
      $$PmcsFaultsTableTableManager(_db, _db.pmcsFaults);
  $$PmcsReportsTableTableManager get pmcsReports =>
      $$PmcsReportsTableTableManager(_db, _db.pmcsReports);
  $$QueuedSubmissionsTableTableManager get queuedSubmissions =>
      $$QueuedSubmissionsTableTableManager(_db, _db.queuedSubmissions);
}
