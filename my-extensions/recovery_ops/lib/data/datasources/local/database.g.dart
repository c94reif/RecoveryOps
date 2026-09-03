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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _callSignMeta =
      const VerificationMeta('callSign');
  @override
  late final GeneratedColumn<String> callSign = GeneratedColumn<String>(
      'call_sign', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, name, callSign, unit];
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
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('call_sign')) {
      context.handle(_callSignMeta,
          callSign.isAcceptableOrUnknown(data['call_sign']!, _callSignMeta));
    } else if (isInserting) {
      context.missing(_callSignMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    } else if (isInserting) {
      context.missing(_unitMeta);
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
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      callSign: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}call_sign'])!,
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class ProfileData extends DataClass implements Insertable<ProfileData> {
  final int id;
  final String name;
  final String callSign;
  final String unit;
  const ProfileData(
      {required this.id,
      required this.name,
      required this.callSign,
      required this.unit});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['call_sign'] = Variable<String>(callSign);
    map['unit'] = Variable<String>(unit);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      name: Value(name),
      callSign: Value(callSign),
      unit: Value(unit),
    );
  }

  factory ProfileData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      callSign: serializer.fromJson<String>(json['callSign']),
      unit: serializer.fromJson<String>(json['unit']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'callSign': serializer.toJson<String>(callSign),
      'unit': serializer.toJson<String>(unit),
    };
  }

  ProfileData copyWith(
          {int? id, String? name, String? callSign, String? unit}) =>
      ProfileData(
        id: id ?? this.id,
        name: name ?? this.name,
        callSign: callSign ?? this.callSign,
        unit: unit ?? this.unit,
      );
  ProfileData copyWithCompanion(ProfilesCompanion data) {
    return ProfileData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      callSign: data.callSign.present ? data.callSign.value : this.callSign,
      unit: data.unit.present ? data.unit.value : this.unit,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('callSign: $callSign, ')
          ..write('unit: $unit')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, callSign, unit);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileData &&
          other.id == this.id &&
          other.name == this.name &&
          other.callSign == this.callSign &&
          other.unit == this.unit);
}

class ProfilesCompanion extends UpdateCompanion<ProfileData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> callSign;
  final Value<String> unit;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.callSign = const Value.absent(),
    this.unit = const Value.absent(),
  });
  ProfilesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String callSign,
    required String unit,
  })  : name = Value(name),
        callSign = Value(callSign),
        unit = Value(unit);
  static Insertable<ProfileData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? callSign,
    Expression<String>? unit,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (callSign != null) 'call_sign': callSign,
      if (unit != null) 'unit': unit,
    });
  }

  ProfilesCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? callSign,
      Value<String>? unit}) {
    return ProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      callSign: callSign ?? this.callSign,
      unit: unit ?? this.unit,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (callSign.present) {
      map['call_sign'] = Variable<String>(callSign.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('callSign: $callSign, ')
          ..write('unit: $unit')
          ..write(')'))
        .toString();
  }
}

class $ReportsTable extends Reports with TableInfo<$ReportsTable, ReportData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReportsTable(this.attachedDatabase, [this._alias]);
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
      'entity_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
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
  static const VerificationMeta _issueMeta = const VerificationMeta('issue');
  @override
  late final GeneratedColumn<String> issue = GeneratedColumn<String>(
      'issue', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recoveryTypeMeta =
      const VerificationMeta('recoveryType');
  @override
  late final GeneratedColumn<String> recoveryType = GeneratedColumn<String>(
      'recovery_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
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
  static const VerificationMeta _navigatorLatitudeMeta =
      const VerificationMeta('navigatorLatitude');
  @override
  late final GeneratedColumn<double> navigatorLatitude =
      GeneratedColumn<double>('navigator_latitude', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _navigatorLongitudeMeta =
      const VerificationMeta('navigatorLongitude');
  @override
  late final GeneratedColumn<double> navigatorLongitude =
      GeneratedColumn<double>('navigator_longitude', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _routeGeometryMeta =
      const VerificationMeta('routeGeometry');
  @override
  late final GeneratedColumn<String> routeGeometry = GeneratedColumn<String>(
      'route_geometry', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
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
        issue,
        recoveryType,
        latitude,
        longitude,
        navigatorLatitude,
        navigatorLongitude,
        timestamp,
        routeGeometry,
        isOutgoing,
        isRead
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reports';
  @override
  VerificationContext validateIntegrity(Insertable<ReportData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
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
    if (data.containsKey('issue')) {
      context.handle(
          _issueMeta, issue.isAcceptableOrUnknown(data['issue']!, _issueMeta));
    } else if (isInserting) {
      context.missing(_issueMeta);
    }
    if (data.containsKey('recovery_type')) {
      context.handle(
          _recoveryTypeMeta,
          recoveryType.isAcceptableOrUnknown(
              data['recovery_type']!, _recoveryTypeMeta));
    } else if (isInserting) {
      context.missing(_recoveryTypeMeta);
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
    if (data.containsKey('navigator_latitude')) {
      context.handle(
          _navigatorLatitudeMeta,
          navigatorLatitude.isAcceptableOrUnknown(
              data['navigator_latitude']!, _navigatorLatitudeMeta));
    }
    if (data.containsKey('navigator_longitude')) {
      context.handle(
          _navigatorLongitudeMeta,
          navigatorLongitude.isAcceptableOrUnknown(
              data['navigator_longitude']!, _navigatorLongitudeMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('route_geometry')) {
      context.handle(
          _routeGeometryMeta,
          routeGeometry.isAcceptableOrUnknown(
              data['route_geometry']!, _routeGeometryMeta));
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
  ReportData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReportData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id']),
      fromCallsign: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}from_callsign'])!,
      bumperNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bumper_number'])!,
      issue: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}issue'])!,
      recoveryType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recovery_type'])!,
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude'])!,
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude'])!,
      navigatorLatitude: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}navigator_latitude']),
      navigatorLongitude: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}navigator_longitude']),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      routeGeometry: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}route_geometry']),
      isOutgoing: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_outgoing'])!,
      isRead: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_read'])!,
    );
  }

  @override
  $ReportsTable createAlias(String alias) {
    return $ReportsTable(attachedDatabase, alias);
  }
}

class ReportData extends DataClass implements Insertable<ReportData> {
  final int id;
  final String? entityId;
  final String fromCallsign;
  final String bumperNumber;
  final String issue;
  final String recoveryType;
  final double latitude;
  final double longitude;
  final double? navigatorLatitude;
  final double? navigatorLongitude;
  final DateTime timestamp;
  final String? routeGeometry;
  final bool isOutgoing;
  final bool isRead;
  const ReportData(
      {required this.id,
      this.entityId,
      required this.fromCallsign,
      required this.bumperNumber,
      required this.issue,
      required this.recoveryType,
      required this.latitude,
      required this.longitude,
      this.navigatorLatitude,
      this.navigatorLongitude,
      required this.timestamp,
      this.routeGeometry,
      required this.isOutgoing,
      required this.isRead});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || entityId != null) {
      map['entity_id'] = Variable<String>(entityId);
    }
    map['from_callsign'] = Variable<String>(fromCallsign);
    map['bumper_number'] = Variable<String>(bumperNumber);
    map['issue'] = Variable<String>(issue);
    map['recovery_type'] = Variable<String>(recoveryType);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    if (!nullToAbsent || navigatorLatitude != null) {
      map['navigator_latitude'] = Variable<double>(navigatorLatitude);
    }
    if (!nullToAbsent || navigatorLongitude != null) {
      map['navigator_longitude'] = Variable<double>(navigatorLongitude);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || routeGeometry != null) {
      map['route_geometry'] = Variable<String>(routeGeometry);
    }
    map['is_outgoing'] = Variable<bool>(isOutgoing);
    map['is_read'] = Variable<bool>(isRead);
    return map;
  }

  ReportsCompanion toCompanion(bool nullToAbsent) {
    return ReportsCompanion(
      id: Value(id),
      entityId: entityId == null && nullToAbsent
          ? const Value.absent()
          : Value(entityId),
      fromCallsign: Value(fromCallsign),
      bumperNumber: Value(bumperNumber),
      issue: Value(issue),
      recoveryType: Value(recoveryType),
      latitude: Value(latitude),
      longitude: Value(longitude),
      navigatorLatitude: navigatorLatitude == null && nullToAbsent
          ? const Value.absent()
          : Value(navigatorLatitude),
      navigatorLongitude: navigatorLongitude == null && nullToAbsent
          ? const Value.absent()
          : Value(navigatorLongitude),
      timestamp: Value(timestamp),
      routeGeometry: routeGeometry == null && nullToAbsent
          ? const Value.absent()
          : Value(routeGeometry),
      isOutgoing: Value(isOutgoing),
      isRead: Value(isRead),
    );
  }

  factory ReportData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReportData(
      id: serializer.fromJson<int>(json['id']),
      entityId: serializer.fromJson<String?>(json['entityId']),
      fromCallsign: serializer.fromJson<String>(json['fromCallsign']),
      bumperNumber: serializer.fromJson<String>(json['bumperNumber']),
      issue: serializer.fromJson<String>(json['issue']),
      recoveryType: serializer.fromJson<String>(json['recoveryType']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      navigatorLatitude:
          serializer.fromJson<double?>(json['navigatorLatitude']),
      navigatorLongitude:
          serializer.fromJson<double?>(json['navigatorLongitude']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      routeGeometry: serializer.fromJson<String?>(json['routeGeometry']),
      isOutgoing: serializer.fromJson<bool>(json['isOutgoing']),
      isRead: serializer.fromJson<bool>(json['isRead']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityId': serializer.toJson<String?>(entityId),
      'fromCallsign': serializer.toJson<String>(fromCallsign),
      'bumperNumber': serializer.toJson<String>(bumperNumber),
      'issue': serializer.toJson<String>(issue),
      'recoveryType': serializer.toJson<String>(recoveryType),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'navigatorLatitude': serializer.toJson<double?>(navigatorLatitude),
      'navigatorLongitude': serializer.toJson<double?>(navigatorLongitude),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'routeGeometry': serializer.toJson<String?>(routeGeometry),
      'isOutgoing': serializer.toJson<bool>(isOutgoing),
      'isRead': serializer.toJson<bool>(isRead),
    };
  }

  ReportData copyWith(
          {int? id,
          Value<String?> entityId = const Value.absent(),
          String? fromCallsign,
          String? bumperNumber,
          String? issue,
          String? recoveryType,
          double? latitude,
          double? longitude,
          Value<double?> navigatorLatitude = const Value.absent(),
          Value<double?> navigatorLongitude = const Value.absent(),
          DateTime? timestamp,
          Value<String?> routeGeometry = const Value.absent(),
          bool? isOutgoing,
          bool? isRead}) =>
      ReportData(
        id: id ?? this.id,
        entityId: entityId.present ? entityId.value : this.entityId,
        fromCallsign: fromCallsign ?? this.fromCallsign,
        bumperNumber: bumperNumber ?? this.bumperNumber,
        issue: issue ?? this.issue,
        recoveryType: recoveryType ?? this.recoveryType,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        navigatorLatitude: navigatorLatitude.present
            ? navigatorLatitude.value
            : this.navigatorLatitude,
        navigatorLongitude: navigatorLongitude.present
            ? navigatorLongitude.value
            : this.navigatorLongitude,
        timestamp: timestamp ?? this.timestamp,
        routeGeometry:
            routeGeometry.present ? routeGeometry.value : this.routeGeometry,
        isOutgoing: isOutgoing ?? this.isOutgoing,
        isRead: isRead ?? this.isRead,
      );
  ReportData copyWithCompanion(ReportsCompanion data) {
    return ReportData(
      id: data.id.present ? data.id.value : this.id,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      fromCallsign: data.fromCallsign.present
          ? data.fromCallsign.value
          : this.fromCallsign,
      bumperNumber: data.bumperNumber.present
          ? data.bumperNumber.value
          : this.bumperNumber,
      issue: data.issue.present ? data.issue.value : this.issue,
      recoveryType: data.recoveryType.present
          ? data.recoveryType.value
          : this.recoveryType,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      navigatorLatitude: data.navigatorLatitude.present
          ? data.navigatorLatitude.value
          : this.navigatorLatitude,
      navigatorLongitude: data.navigatorLongitude.present
          ? data.navigatorLongitude.value
          : this.navigatorLongitude,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      routeGeometry: data.routeGeometry.present
          ? data.routeGeometry.value
          : this.routeGeometry,
      isOutgoing:
          data.isOutgoing.present ? data.isOutgoing.value : this.isOutgoing,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReportData(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('fromCallsign: $fromCallsign, ')
          ..write('bumperNumber: $bumperNumber, ')
          ..write('issue: $issue, ')
          ..write('recoveryType: $recoveryType, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('navigatorLatitude: $navigatorLatitude, ')
          ..write('navigatorLongitude: $navigatorLongitude, ')
          ..write('timestamp: $timestamp, ')
          ..write('routeGeometry: $routeGeometry, ')
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
      issue,
      recoveryType,
      latitude,
      longitude,
      navigatorLatitude,
      navigatorLongitude,
      timestamp,
      routeGeometry,
      isOutgoing,
      isRead);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReportData &&
          other.id == this.id &&
          other.entityId == this.entityId &&
          other.fromCallsign == this.fromCallsign &&
          other.bumperNumber == this.bumperNumber &&
          other.issue == this.issue &&
          other.recoveryType == this.recoveryType &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.navigatorLatitude == this.navigatorLatitude &&
          other.navigatorLongitude == this.navigatorLongitude &&
          other.timestamp == this.timestamp &&
          other.routeGeometry == this.routeGeometry &&
          other.isOutgoing == this.isOutgoing &&
          other.isRead == this.isRead);
}

class ReportsCompanion extends UpdateCompanion<ReportData> {
  final Value<int> id;
  final Value<String?> entityId;
  final Value<String> fromCallsign;
  final Value<String> bumperNumber;
  final Value<String> issue;
  final Value<String> recoveryType;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<double?> navigatorLatitude;
  final Value<double?> navigatorLongitude;
  final Value<DateTime> timestamp;
  final Value<String?> routeGeometry;
  final Value<bool> isOutgoing;
  final Value<bool> isRead;
  const ReportsCompanion({
    this.id = const Value.absent(),
    this.entityId = const Value.absent(),
    this.fromCallsign = const Value.absent(),
    this.bumperNumber = const Value.absent(),
    this.issue = const Value.absent(),
    this.recoveryType = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.navigatorLatitude = const Value.absent(),
    this.navigatorLongitude = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.routeGeometry = const Value.absent(),
    this.isOutgoing = const Value.absent(),
    this.isRead = const Value.absent(),
  });
  ReportsCompanion.insert({
    this.id = const Value.absent(),
    this.entityId = const Value.absent(),
    required String fromCallsign,
    required String bumperNumber,
    required String issue,
    required String recoveryType,
    required double latitude,
    required double longitude,
    this.navigatorLatitude = const Value.absent(),
    this.navigatorLongitude = const Value.absent(),
    required DateTime timestamp,
    this.routeGeometry = const Value.absent(),
    this.isOutgoing = const Value.absent(),
    this.isRead = const Value.absent(),
  })  : fromCallsign = Value(fromCallsign),
        bumperNumber = Value(bumperNumber),
        issue = Value(issue),
        recoveryType = Value(recoveryType),
        latitude = Value(latitude),
        longitude = Value(longitude),
        timestamp = Value(timestamp);
  static Insertable<ReportData> custom({
    Expression<int>? id,
    Expression<String>? entityId,
    Expression<String>? fromCallsign,
    Expression<String>? bumperNumber,
    Expression<String>? issue,
    Expression<String>? recoveryType,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? navigatorLatitude,
    Expression<double>? navigatorLongitude,
    Expression<DateTime>? timestamp,
    Expression<String>? routeGeometry,
    Expression<bool>? isOutgoing,
    Expression<bool>? isRead,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityId != null) 'entity_id': entityId,
      if (fromCallsign != null) 'from_callsign': fromCallsign,
      if (bumperNumber != null) 'bumper_number': bumperNumber,
      if (issue != null) 'issue': issue,
      if (recoveryType != null) 'recovery_type': recoveryType,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (navigatorLatitude != null) 'navigator_latitude': navigatorLatitude,
      if (navigatorLongitude != null) 'navigator_longitude': navigatorLongitude,
      if (timestamp != null) 'timestamp': timestamp,
      if (routeGeometry != null) 'route_geometry': routeGeometry,
      if (isOutgoing != null) 'is_outgoing': isOutgoing,
      if (isRead != null) 'is_read': isRead,
    });
  }

  ReportsCompanion copyWith(
      {Value<int>? id,
      Value<String?>? entityId,
      Value<String>? fromCallsign,
      Value<String>? bumperNumber,
      Value<String>? issue,
      Value<String>? recoveryType,
      Value<double>? latitude,
      Value<double>? longitude,
      Value<double?>? navigatorLatitude,
      Value<double?>? navigatorLongitude,
      Value<DateTime>? timestamp,
      Value<String?>? routeGeometry,
      Value<bool>? isOutgoing,
      Value<bool>? isRead}) {
    return ReportsCompanion(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      fromCallsign: fromCallsign ?? this.fromCallsign,
      bumperNumber: bumperNumber ?? this.bumperNumber,
      issue: issue ?? this.issue,
      recoveryType: recoveryType ?? this.recoveryType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      navigatorLatitude: navigatorLatitude ?? this.navigatorLatitude,
      navigatorLongitude: navigatorLongitude ?? this.navigatorLongitude,
      timestamp: timestamp ?? this.timestamp,
      routeGeometry: routeGeometry ?? this.routeGeometry,
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
    if (issue.present) {
      map['issue'] = Variable<String>(issue.value);
    }
    if (recoveryType.present) {
      map['recovery_type'] = Variable<String>(recoveryType.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (navigatorLatitude.present) {
      map['navigator_latitude'] = Variable<double>(navigatorLatitude.value);
    }
    if (navigatorLongitude.present) {
      map['navigator_longitude'] = Variable<double>(navigatorLongitude.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (routeGeometry.present) {
      map['route_geometry'] = Variable<String>(routeGeometry.value);
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
    return (StringBuffer('ReportsCompanion(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('fromCallsign: $fromCallsign, ')
          ..write('bumperNumber: $bumperNumber, ')
          ..write('issue: $issue, ')
          ..write('recoveryType: $recoveryType, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('navigatorLatitude: $navigatorLatitude, ')
          ..write('navigatorLongitude: $navigatorLongitude, ')
          ..write('timestamp: $timestamp, ')
          ..write('routeGeometry: $routeGeometry, ')
          ..write('isOutgoing: $isOutgoing, ')
          ..write('isRead: $isRead')
          ..write(')'))
        .toString();
  }
}

class $QueuedRequestsTable extends QueuedRequests
    with TableInfo<$QueuedRequestsTable, QueuedRequestData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueuedRequestsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _issueMeta = const VerificationMeta('issue');
  @override
  late final GeneratedColumn<String> issue = GeneratedColumn<String>(
      'issue', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recoveryTypeMeta =
      const VerificationMeta('recoveryType');
  @override
  late final GeneratedColumn<String> recoveryType = GeneratedColumn<String>(
      'recovery_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
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
        issue,
        recoveryType,
        latitude,
        longitude,
        transport,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queued_requests';
  @override
  VerificationContext validateIntegrity(Insertable<QueuedRequestData> instance,
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
    if (data.containsKey('issue')) {
      context.handle(
          _issueMeta, issue.isAcceptableOrUnknown(data['issue']!, _issueMeta));
    } else if (isInserting) {
      context.missing(_issueMeta);
    }
    if (data.containsKey('recovery_type')) {
      context.handle(
          _recoveryTypeMeta,
          recoveryType.isAcceptableOrUnknown(
              data['recovery_type']!, _recoveryTypeMeta));
    } else if (isInserting) {
      context.missing(_recoveryTypeMeta);
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
  QueuedRequestData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueuedRequestData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id'])!,
      bumperNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bumper_number'])!,
      issue: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}issue'])!,
      recoveryType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recovery_type'])!,
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude'])!,
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude'])!,
      transport: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}transport'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $QueuedRequestsTable createAlias(String alias) {
    return $QueuedRequestsTable(attachedDatabase, alias);
  }
}

class QueuedRequestData extends DataClass
    implements Insertable<QueuedRequestData> {
  final int id;
  final String entityId;
  final String bumperNumber;
  final String issue;
  final String recoveryType;
  final double latitude;
  final double longitude;
  final String transport;
  final DateTime createdAt;
  const QueuedRequestData(
      {required this.id,
      required this.entityId,
      required this.bumperNumber,
      required this.issue,
      required this.recoveryType,
      required this.latitude,
      required this.longitude,
      required this.transport,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_id'] = Variable<String>(entityId);
    map['bumper_number'] = Variable<String>(bumperNumber);
    map['issue'] = Variable<String>(issue);
    map['recovery_type'] = Variable<String>(recoveryType);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['transport'] = Variable<String>(transport);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  QueuedRequestsCompanion toCompanion(bool nullToAbsent) {
    return QueuedRequestsCompanion(
      id: Value(id),
      entityId: Value(entityId),
      bumperNumber: Value(bumperNumber),
      issue: Value(issue),
      recoveryType: Value(recoveryType),
      latitude: Value(latitude),
      longitude: Value(longitude),
      transport: Value(transport),
      createdAt: Value(createdAt),
    );
  }

  factory QueuedRequestData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueuedRequestData(
      id: serializer.fromJson<int>(json['id']),
      entityId: serializer.fromJson<String>(json['entityId']),
      bumperNumber: serializer.fromJson<String>(json['bumperNumber']),
      issue: serializer.fromJson<String>(json['issue']),
      recoveryType: serializer.fromJson<String>(json['recoveryType']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
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
      'issue': serializer.toJson<String>(issue),
      'recoveryType': serializer.toJson<String>(recoveryType),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'transport': serializer.toJson<String>(transport),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  QueuedRequestData copyWith(
          {int? id,
          String? entityId,
          String? bumperNumber,
          String? issue,
          String? recoveryType,
          double? latitude,
          double? longitude,
          String? transport,
          DateTime? createdAt}) =>
      QueuedRequestData(
        id: id ?? this.id,
        entityId: entityId ?? this.entityId,
        bumperNumber: bumperNumber ?? this.bumperNumber,
        issue: issue ?? this.issue,
        recoveryType: recoveryType ?? this.recoveryType,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        transport: transport ?? this.transport,
        createdAt: createdAt ?? this.createdAt,
      );
  QueuedRequestData copyWithCompanion(QueuedRequestsCompanion data) {
    return QueuedRequestData(
      id: data.id.present ? data.id.value : this.id,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      bumperNumber: data.bumperNumber.present
          ? data.bumperNumber.value
          : this.bumperNumber,
      issue: data.issue.present ? data.issue.value : this.issue,
      recoveryType: data.recoveryType.present
          ? data.recoveryType.value
          : this.recoveryType,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      transport: data.transport.present ? data.transport.value : this.transport,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueuedRequestData(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('bumperNumber: $bumperNumber, ')
          ..write('issue: $issue, ')
          ..write('recoveryType: $recoveryType, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('transport: $transport, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, entityId, bumperNumber, issue,
      recoveryType, latitude, longitude, transport, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueuedRequestData &&
          other.id == this.id &&
          other.entityId == this.entityId &&
          other.bumperNumber == this.bumperNumber &&
          other.issue == this.issue &&
          other.recoveryType == this.recoveryType &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.transport == this.transport &&
          other.createdAt == this.createdAt);
}

class QueuedRequestsCompanion extends UpdateCompanion<QueuedRequestData> {
  final Value<int> id;
  final Value<String> entityId;
  final Value<String> bumperNumber;
  final Value<String> issue;
  final Value<String> recoveryType;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<String> transport;
  final Value<DateTime> createdAt;
  const QueuedRequestsCompanion({
    this.id = const Value.absent(),
    this.entityId = const Value.absent(),
    this.bumperNumber = const Value.absent(),
    this.issue = const Value.absent(),
    this.recoveryType = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.transport = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  QueuedRequestsCompanion.insert({
    this.id = const Value.absent(),
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String recoveryType,
    required double latitude,
    required double longitude,
    required String transport,
    required DateTime createdAt,
  })  : entityId = Value(entityId),
        bumperNumber = Value(bumperNumber),
        issue = Value(issue),
        recoveryType = Value(recoveryType),
        latitude = Value(latitude),
        longitude = Value(longitude),
        transport = Value(transport),
        createdAt = Value(createdAt);
  static Insertable<QueuedRequestData> custom({
    Expression<int>? id,
    Expression<String>? entityId,
    Expression<String>? bumperNumber,
    Expression<String>? issue,
    Expression<String>? recoveryType,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? transport,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityId != null) 'entity_id': entityId,
      if (bumperNumber != null) 'bumper_number': bumperNumber,
      if (issue != null) 'issue': issue,
      if (recoveryType != null) 'recovery_type': recoveryType,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (transport != null) 'transport': transport,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  QueuedRequestsCompanion copyWith(
      {Value<int>? id,
      Value<String>? entityId,
      Value<String>? bumperNumber,
      Value<String>? issue,
      Value<String>? recoveryType,
      Value<double>? latitude,
      Value<double>? longitude,
      Value<String>? transport,
      Value<DateTime>? createdAt}) {
    return QueuedRequestsCompanion(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      bumperNumber: bumperNumber ?? this.bumperNumber,
      issue: issue ?? this.issue,
      recoveryType: recoveryType ?? this.recoveryType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
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
    if (issue.present) {
      map['issue'] = Variable<String>(issue.value);
    }
    if (recoveryType.present) {
      map['recovery_type'] = Variable<String>(recoveryType.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
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
    return (StringBuffer('QueuedRequestsCompanion(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('bumperNumber: $bumperNumber, ')
          ..write('issue: $issue, ')
          ..write('recoveryType: $recoveryType, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
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
  late final $ReportsTable reports = $ReportsTable(this);
  late final $QueuedRequestsTable queuedRequests = $QueuedRequestsTable(this);
  late final ProfileDao profileDao = ProfileDao(this as AppDatabase);
  late final ReportsDao reportsDao = ReportsDao(this as AppDatabase);
  late final QueuedRequestsDao queuedRequestsDao =
      QueuedRequestsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [profiles, reports, queuedRequests];
}

typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  Value<int> id,
  required String name,
  required String callSign,
  required String unit,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> callSign,
  Value<String> unit,
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

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get callSign => $composableBuilder(
      column: $table.callSign, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));
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

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get callSign => $composableBuilder(
      column: $table.callSign, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));
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

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get callSign =>
      $composableBuilder(column: $table.callSign, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);
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
            Value<String> name = const Value.absent(),
            Value<String> callSign = const Value.absent(),
            Value<String> unit = const Value.absent(),
          }) =>
              ProfilesCompanion(
            id: id,
            name: name,
            callSign: callSign,
            unit: unit,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required String callSign,
            required String unit,
          }) =>
              ProfilesCompanion.insert(
            id: id,
            name: name,
            callSign: callSign,
            unit: unit,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
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
typedef $$ReportsTableCreateCompanionBuilder = ReportsCompanion Function({
  Value<int> id,
  Value<String?> entityId,
  required String fromCallsign,
  required String bumperNumber,
  required String issue,
  required String recoveryType,
  required double latitude,
  required double longitude,
  Value<double?> navigatorLatitude,
  Value<double?> navigatorLongitude,
  required DateTime timestamp,
  Value<String?> routeGeometry,
  Value<bool> isOutgoing,
  Value<bool> isRead,
});
typedef $$ReportsTableUpdateCompanionBuilder = ReportsCompanion Function({
  Value<int> id,
  Value<String?> entityId,
  Value<String> fromCallsign,
  Value<String> bumperNumber,
  Value<String> issue,
  Value<String> recoveryType,
  Value<double> latitude,
  Value<double> longitude,
  Value<double?> navigatorLatitude,
  Value<double?> navigatorLongitude,
  Value<DateTime> timestamp,
  Value<String?> routeGeometry,
  Value<bool> isOutgoing,
  Value<bool> isRead,
});

class $$ReportsTableFilterComposer
    extends Composer<_$AppDatabase, $ReportsTable> {
  $$ReportsTableFilterComposer({
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

  ColumnFilters<String> get issue => $composableBuilder(
      column: $table.issue, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recoveryType => $composableBuilder(
      column: $table.recoveryType, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get navigatorLatitude => $composableBuilder(
      column: $table.navigatorLatitude,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get navigatorLongitude => $composableBuilder(
      column: $table.navigatorLongitude,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get routeGeometry => $composableBuilder(
      column: $table.routeGeometry, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isOutgoing => $composableBuilder(
      column: $table.isOutgoing, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isRead => $composableBuilder(
      column: $table.isRead, builder: (column) => ColumnFilters(column));
}

class $$ReportsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReportsTable> {
  $$ReportsTableOrderingComposer({
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

  ColumnOrderings<String> get issue => $composableBuilder(
      column: $table.issue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recoveryType => $composableBuilder(
      column: $table.recoveryType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get navigatorLatitude => $composableBuilder(
      column: $table.navigatorLatitude,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get navigatorLongitude => $composableBuilder(
      column: $table.navigatorLongitude,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get routeGeometry => $composableBuilder(
      column: $table.routeGeometry,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isOutgoing => $composableBuilder(
      column: $table.isOutgoing, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isRead => $composableBuilder(
      column: $table.isRead, builder: (column) => ColumnOrderings(column));
}

class $$ReportsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReportsTable> {
  $$ReportsTableAnnotationComposer({
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

  GeneratedColumn<String> get issue =>
      $composableBuilder(column: $table.issue, builder: (column) => column);

  GeneratedColumn<String> get recoveryType => $composableBuilder(
      column: $table.recoveryType, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get navigatorLatitude => $composableBuilder(
      column: $table.navigatorLatitude, builder: (column) => column);

  GeneratedColumn<double> get navigatorLongitude => $composableBuilder(
      column: $table.navigatorLongitude, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get routeGeometry => $composableBuilder(
      column: $table.routeGeometry, builder: (column) => column);

  GeneratedColumn<bool> get isOutgoing => $composableBuilder(
      column: $table.isOutgoing, builder: (column) => column);

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);
}

class $$ReportsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReportsTable,
    ReportData,
    $$ReportsTableFilterComposer,
    $$ReportsTableOrderingComposer,
    $$ReportsTableAnnotationComposer,
    $$ReportsTableCreateCompanionBuilder,
    $$ReportsTableUpdateCompanionBuilder,
    (ReportData, BaseReferences<_$AppDatabase, $ReportsTable, ReportData>),
    ReportData,
    PrefetchHooks Function()> {
  $$ReportsTableTableManager(_$AppDatabase db, $ReportsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> entityId = const Value.absent(),
            Value<String> fromCallsign = const Value.absent(),
            Value<String> bumperNumber = const Value.absent(),
            Value<String> issue = const Value.absent(),
            Value<String> recoveryType = const Value.absent(),
            Value<double> latitude = const Value.absent(),
            Value<double> longitude = const Value.absent(),
            Value<double?> navigatorLatitude = const Value.absent(),
            Value<double?> navigatorLongitude = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String?> routeGeometry = const Value.absent(),
            Value<bool> isOutgoing = const Value.absent(),
            Value<bool> isRead = const Value.absent(),
          }) =>
              ReportsCompanion(
            id: id,
            entityId: entityId,
            fromCallsign: fromCallsign,
            bumperNumber: bumperNumber,
            issue: issue,
            recoveryType: recoveryType,
            latitude: latitude,
            longitude: longitude,
            navigatorLatitude: navigatorLatitude,
            navigatorLongitude: navigatorLongitude,
            timestamp: timestamp,
            routeGeometry: routeGeometry,
            isOutgoing: isOutgoing,
            isRead: isRead,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> entityId = const Value.absent(),
            required String fromCallsign,
            required String bumperNumber,
            required String issue,
            required String recoveryType,
            required double latitude,
            required double longitude,
            Value<double?> navigatorLatitude = const Value.absent(),
            Value<double?> navigatorLongitude = const Value.absent(),
            required DateTime timestamp,
            Value<String?> routeGeometry = const Value.absent(),
            Value<bool> isOutgoing = const Value.absent(),
            Value<bool> isRead = const Value.absent(),
          }) =>
              ReportsCompanion.insert(
            id: id,
            entityId: entityId,
            fromCallsign: fromCallsign,
            bumperNumber: bumperNumber,
            issue: issue,
            recoveryType: recoveryType,
            latitude: latitude,
            longitude: longitude,
            navigatorLatitude: navigatorLatitude,
            navigatorLongitude: navigatorLongitude,
            timestamp: timestamp,
            routeGeometry: routeGeometry,
            isOutgoing: isOutgoing,
            isRead: isRead,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ReportsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReportsTable,
    ReportData,
    $$ReportsTableFilterComposer,
    $$ReportsTableOrderingComposer,
    $$ReportsTableAnnotationComposer,
    $$ReportsTableCreateCompanionBuilder,
    $$ReportsTableUpdateCompanionBuilder,
    (ReportData, BaseReferences<_$AppDatabase, $ReportsTable, ReportData>),
    ReportData,
    PrefetchHooks Function()>;
typedef $$QueuedRequestsTableCreateCompanionBuilder = QueuedRequestsCompanion
    Function({
  Value<int> id,
  required String entityId,
  required String bumperNumber,
  required String issue,
  required String recoveryType,
  required double latitude,
  required double longitude,
  required String transport,
  required DateTime createdAt,
});
typedef $$QueuedRequestsTableUpdateCompanionBuilder = QueuedRequestsCompanion
    Function({
  Value<int> id,
  Value<String> entityId,
  Value<String> bumperNumber,
  Value<String> issue,
  Value<String> recoveryType,
  Value<double> latitude,
  Value<double> longitude,
  Value<String> transport,
  Value<DateTime> createdAt,
});

class $$QueuedRequestsTableFilterComposer
    extends Composer<_$AppDatabase, $QueuedRequestsTable> {
  $$QueuedRequestsTableFilterComposer({
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

  ColumnFilters<String> get issue => $composableBuilder(
      column: $table.issue, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recoveryType => $composableBuilder(
      column: $table.recoveryType, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get transport => $composableBuilder(
      column: $table.transport, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$QueuedRequestsTableOrderingComposer
    extends Composer<_$AppDatabase, $QueuedRequestsTable> {
  $$QueuedRequestsTableOrderingComposer({
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

  ColumnOrderings<String> get issue => $composableBuilder(
      column: $table.issue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recoveryType => $composableBuilder(
      column: $table.recoveryType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get transport => $composableBuilder(
      column: $table.transport, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$QueuedRequestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QueuedRequestsTable> {
  $$QueuedRequestsTableAnnotationComposer({
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

  GeneratedColumn<String> get issue =>
      $composableBuilder(column: $table.issue, builder: (column) => column);

  GeneratedColumn<String> get recoveryType => $composableBuilder(
      column: $table.recoveryType, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get transport =>
      $composableBuilder(column: $table.transport, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$QueuedRequestsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $QueuedRequestsTable,
    QueuedRequestData,
    $$QueuedRequestsTableFilterComposer,
    $$QueuedRequestsTableOrderingComposer,
    $$QueuedRequestsTableAnnotationComposer,
    $$QueuedRequestsTableCreateCompanionBuilder,
    $$QueuedRequestsTableUpdateCompanionBuilder,
    (
      QueuedRequestData,
      BaseReferences<_$AppDatabase, $QueuedRequestsTable, QueuedRequestData>
    ),
    QueuedRequestData,
    PrefetchHooks Function()> {
  $$QueuedRequestsTableTableManager(
      _$AppDatabase db, $QueuedRequestsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueuedRequestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueuedRequestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueuedRequestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> entityId = const Value.absent(),
            Value<String> bumperNumber = const Value.absent(),
            Value<String> issue = const Value.absent(),
            Value<String> recoveryType = const Value.absent(),
            Value<double> latitude = const Value.absent(),
            Value<double> longitude = const Value.absent(),
            Value<String> transport = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              QueuedRequestsCompanion(
            id: id,
            entityId: entityId,
            bumperNumber: bumperNumber,
            issue: issue,
            recoveryType: recoveryType,
            latitude: latitude,
            longitude: longitude,
            transport: transport,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String entityId,
            required String bumperNumber,
            required String issue,
            required String recoveryType,
            required double latitude,
            required double longitude,
            required String transport,
            required DateTime createdAt,
          }) =>
              QueuedRequestsCompanion.insert(
            id: id,
            entityId: entityId,
            bumperNumber: bumperNumber,
            issue: issue,
            recoveryType: recoveryType,
            latitude: latitude,
            longitude: longitude,
            transport: transport,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$QueuedRequestsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $QueuedRequestsTable,
    QueuedRequestData,
    $$QueuedRequestsTableFilterComposer,
    $$QueuedRequestsTableOrderingComposer,
    $$QueuedRequestsTableAnnotationComposer,
    $$QueuedRequestsTableCreateCompanionBuilder,
    $$QueuedRequestsTableUpdateCompanionBuilder,
    (
      QueuedRequestData,
      BaseReferences<_$AppDatabase, $QueuedRequestsTable, QueuedRequestData>
    ),
    QueuedRequestData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$ReportsTableTableManager get reports =>
      $$ReportsTableTableManager(_db, _db.reports);
  $$QueuedRequestsTableTableManager get queuedRequests =>
      $$QueuedRequestsTableTableManager(_db, _db.queuedRequests);
}
