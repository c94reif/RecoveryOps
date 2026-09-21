import 'package:flutter/foundation.dart';

enum Disposition {
  friendly,
  hostile,
  neutral,
  suspicious,
  unknown;

  String get defaultColor {
    switch (this) {
      case Disposition.friendly:
        return '#4A90D9';
      case Disposition.hostile:
        return '#D94A4A';
      case Disposition.neutral:
        return '#4AD94A';
      case Disposition.suspicious:
        return '#D9884A';
      case Disposition.unknown:
        return '#888888';
    }
  }

  String get defaultSymbol {
    switch (this) {
      case Disposition.friendly:
        return 'circle';
      case Disposition.hostile:
        return 'diamond';
      case Disposition.neutral:
        return 'square';
      case Disposition.suspicious:
        return 'diamond';
      case Disposition.unknown:
        return 'circle';
    }
  }
}

enum ShapeType { point, polygon, line, ellipse }

@immutable
class EntityOntology {
  const EntityOntology({
    this.platformType,
    this.specificType,
    this.template,
  });

  final String? platformType;
  final String? specificType;
  final String? template;

  factory EntityOntology.fromJson(Map<String, dynamic> json) => EntityOntology(
        platformType: json['platformType'] as String?,
        specificType: json['specificType'] as String?,
        template: json['template'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (platformType != null) 'platformType': platformType,
        if (specificType != null) 'specificType': specificType,
        if (template != null) 'template': template,
      };
}

@immutable
class EntityProvenance {
  const EntityProvenance({
    this.integrationName,
    this.dataType,
    this.sourceUpdateTime,
    this.sourceId,
  });

  final String? integrationName;
  final String? dataType;
  final String? sourceUpdateTime;
  final String? sourceId;

  factory EntityProvenance.fromJson(Map<String, dynamic> json) =>
      EntityProvenance(
        integrationName: json['integrationName'] as String?,
        dataType: json['dataType'] as String?,
        sourceUpdateTime: json['sourceUpdateTime'] as String?,
        sourceId: json['sourceId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (integrationName != null) 'integrationName': integrationName,
        if (dataType != null) 'dataType': dataType,
        if (sourceUpdateTime != null) 'sourceUpdateTime': sourceUpdateTime,
        if (sourceId != null) 'sourceId': sourceId,
      };
}

@immutable
class EntityStatus {
  const EntityStatus({
    this.platformActivity,
    this.role,
  });

  final String? platformActivity;
  final String? role;

  factory EntityStatus.fromJson(Map<String, dynamic> json) => EntityStatus(
        platformActivity: json['platformActivity'] as String?,
        role: json['role'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (platformActivity != null) 'platformActivity': platformActivity,
        if (role != null) 'role': role,
      };
}

@immutable
class AlternateId {
  const AlternateId({required this.id, required this.type});

  final String id;
  final String type;

  factory AlternateId.fromJson(Map<String, dynamic> json) => AlternateId(
        id: json['id'] as String,
        type: json['type'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'type': type};
}

@immutable
class Entity {
  const Entity({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.disposition,
    this.shapeType = ShapeType.point,
    this.color,
    this.symbol,
    this.extra,
    this.taskCatalog = const [],
    this.description,
    this.environment,
    this.ontology,
    this.provenance,
    this.status,
    this.alternateIds = const [],
    this.expiryTime,
    this.createdTime,
    this.isLive,
    this.routeDetails,
    this.ring,
    this.altFloorMeters,
    this.altCeilMeters,
    this.startTime,
    this.geoDetailsBytes,
    this.linePositions,
    this.sidc,
    this.prototypeExtensionsBytes,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
  final Disposition disposition;
  final ShapeType shapeType;
  final String? color;
  final String? symbol;
  final Map<String, dynamic>? extra;
  final List<String> taskCatalog;
  final String? description;
  final String? environment;
  final EntityOntology? ontology;
  final EntityProvenance? provenance;
  final EntityStatus? status;
  final List<AlternateId> alternateIds;
  final DateTime? expiryTime;
  final DateTime? createdTime;
  final bool? isLive;
  final Map<String, dynamic>? routeDetails;

  /// Polygon ring as [lat, lon] pairs. Only used when [shapeType] is
  /// [ShapeType.polygon]. Must have at least 3 elements.
  final List<List<double>>? ring;

  /// Altitude floor above ground level, in metres. Applied per-vertex on the
  /// polygon ring when building the proto entity.
  final double? altFloorMeters;

  /// Altitude ceiling above ground level, in metres. The extrusion height
  /// (`heightM`) per vertex is computed as `(altCeilMeters - altFloorMeters)`.
  final double? altCeilMeters;

  /// Optional effective start time for the entity. Maps to `entity.createdTime`
  /// on the proto when present.
  final DateTime? startTime;

  /// Optional serialized `GeoDetails` proto, carried opaquely by the platform.
  /// A plugin that owns its geometry builds the full `GeoDetails` message in its
  /// own layer and sets the bytes here; the host attaches them to the published
  /// entity (and echoes them back on read) WITHOUT decoding — it has no
  /// knowledge of any specific geo type or subtype. Null for entities that
  /// carry no geo detail.
  final List<int>? geoDetailsBytes;

  /// Line vertices as [lat, lon] pairs, in order. Only used when [shapeType] is
  /// [ShapeType.line]. Must have at least 2 elements. Unlike [ring], this is NOT
  /// auto-closed — a line is an open path, not a loop. The host builds a
  /// `geoShape.line` (GeoLine) from these and uses their centroid as the
  /// entity's `location`.
  final List<List<double>>? linePositions;

  /// Optional 2525 SIDC. When set, the host stamps `symbology.milStd2525C.sidc`
  /// on the published entity so it renders with doctrinal styling (e.g. a line
  /// control measure like MSR/ASR). Null for entities with no symbology.
  ///
  /// Format: a 20-character MIL-STD-2525D symbol identification code (the same
  /// string the milSymbol renderer consumes). Layout is
  /// `VVSSSSSSSSSSDDDDdddd`:
  ///   - `VV`   version (`10` = 2525D)
  ///   - `S`    standard identity + symbol set + status + HQ/task-force + echelon
  ///   - `D`    the 6-digit entity/mission code
  ///   - `dddd` modifiers (usually `0000`)
  /// A `-` is treated as `0` by the renderer.
  ///
  /// Examples (line control measures, symbol set `25`):
  ///   - `10032500003303000000` — Main Supply Route (MSR)
  ///   - `10032500003304000000` — Alternate Supply Route (ASR)
  ///   - `10032500001403000000` — Phase Line
  ///   - `10032500001101000000` — Boundary
  /// Point example:
  ///   - `10031000001211000000` — friendly infantry
  final String? sidc;

  /// Optional serialized `PrototypeExtensions` proto, carried opaquely by the
  /// platform (same contract as [geoDetailsBytes]). A plugin builds the message
  /// in its own layer — e.g. a `tactical-graphic` extension carrying
  /// `{sidc, category, label}` so the host and LCA desktop classify and label
  /// the entity as a tactical graphic. The host merges these onto the published
  /// entity WITHOUT decoding. Null when the entity carries no extensions.
  final List<int>? prototypeExtensionsBytes;

  String get resolvedColor => color ?? disposition.defaultColor;
  String get resolvedSymbol => symbol ?? disposition.defaultSymbol;

  Entity copyWith({
    String? id,
    String? name,
    double? lat,
    double? lon,
    Disposition? disposition,
    ShapeType? shapeType,
    String? color,
    String? symbol,
    Map<String, dynamic>? extra,
    List<String>? taskCatalog,
    String? description,
    String? environment,
    EntityOntology? ontology,
    EntityProvenance? provenance,
    EntityStatus? status,
    List<AlternateId>? alternateIds,
    DateTime? expiryTime,
    DateTime? createdTime,
    bool? isLive,
    Map<String, dynamic>? routeDetails,
    List<List<double>>? ring,
    double? altFloorMeters,
    double? altCeilMeters,
    DateTime? startTime,
    List<int>? geoDetailsBytes,
    List<List<double>>? linePositions,
    String? sidc,
    List<int>? prototypeExtensionsBytes,
  }) {
    return Entity(
      id: id ?? this.id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      disposition: disposition ?? this.disposition,
      shapeType: shapeType ?? this.shapeType,
      color: color ?? this.color,
      symbol: symbol ?? this.symbol,
      extra: extra ?? this.extra,
      taskCatalog: taskCatalog ?? this.taskCatalog,
      description: description ?? this.description,
      environment: environment ?? this.environment,
      ontology: ontology ?? this.ontology,
      provenance: provenance ?? this.provenance,
      status: status ?? this.status,
      alternateIds: alternateIds ?? this.alternateIds,
      expiryTime: expiryTime ?? this.expiryTime,
      createdTime: createdTime ?? this.createdTime,
      isLive: isLive ?? this.isLive,
      routeDetails: routeDetails ?? this.routeDetails,
      ring: ring ?? this.ring,
      altFloorMeters: altFloorMeters ?? this.altFloorMeters,
      altCeilMeters: altCeilMeters ?? this.altCeilMeters,
      startTime: startTime ?? this.startTime,
      geoDetailsBytes: geoDetailsBytes ?? this.geoDetailsBytes,
      linePositions: linePositions ?? this.linePositions,
      sidc: sidc ?? this.sidc,
      prototypeExtensionsBytes:
          prototypeExtensionsBytes ?? this.prototypeExtensionsBytes,
    );
  }

  factory Entity.fromJson(Map<String, dynamic> json) {
    return Entity(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      disposition: Disposition.values.byName(json['disposition'] as String),
      shapeType: json['shapeType'] != null
          ? ShapeType.values.byName(json['shapeType'] as String)
          : ShapeType.point,
      color: json['color'] as String?,
      symbol: json['symbol'] as String?,
      extra: json['extra'] as Map<String, dynamic>?,
      taskCatalog: (json['taskCatalog'] as List<dynamic>?)
              ?.cast<String>() ??
          const [],
      description: json['description'] as String?,
      environment: json['environment'] as String?,
      ontology: json['ontology'] != null
          ? EntityOntology.fromJson(json['ontology'] as Map<String, dynamic>)
          : null,
      provenance: json['provenance'] != null
          ? EntityProvenance.fromJson(
              json['provenance'] as Map<String, dynamic>)
          : null,
      status: json['status'] != null
          ? EntityStatus.fromJson(json['status'] as Map<String, dynamic>)
          : null,
      alternateIds: (json['alternateIds'] as List<dynamic>?)
              ?.map((e) => AlternateId.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      expiryTime: json['expiryTime'] != null
          ? DateTime.parse(json['expiryTime'] as String)
          : null,
      createdTime: json['createdTime'] != null
          ? DateTime.parse(json['createdTime'] as String)
          : null,
      isLive: json['isLive'] as bool?,
      routeDetails: json['routeDetails'] as Map<String, dynamic>?,
      ring: (json['ring'] as List<dynamic>?)
          ?.map((row) => (row as List<dynamic>).map((v) => (v as num).toDouble()).toList())
          .toList(),
      altFloorMeters: (json['altFloorMeters'] as num?)?.toDouble(),
      altCeilMeters: (json['altCeilMeters'] as num?)?.toDouble(),
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'] as String)
          : null,
      geoDetailsBytes: (json['geoDetailsBytes'] as List<dynamic>?)
          ?.map((v) => (v as num).toInt())
          .toList(),
      linePositions: (json['linePositions'] as List<dynamic>?)
          ?.map((row) =>
              (row as List<dynamic>).map((v) => (v as num).toDouble()).toList())
          .toList(),
      sidc: json['sidc'] as String?,
      prototypeExtensionsBytes: (json['prototypeExtensionsBytes'] as List<dynamic>?)
          ?.map((v) => (v as num).toInt())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lon': lon,
        'disposition': disposition.name,
        'shapeType': shapeType.name,
        if (color != null) 'color': color,
        if (symbol != null) 'symbol': symbol,
        if (extra != null) 'extra': extra,
        if (taskCatalog.isNotEmpty) 'taskCatalog': taskCatalog,
        if (description != null) 'description': description,
        if (environment != null) 'environment': environment,
        if (ontology != null) 'ontology': ontology!.toJson(),
        if (provenance != null) 'provenance': provenance!.toJson(),
        if (status != null) 'status': status!.toJson(),
        if (alternateIds.isNotEmpty)
          'alternateIds': alternateIds.map((a) => a.toJson()).toList(),
        if (expiryTime != null) 'expiryTime': expiryTime!.toIso8601String(),
        if (createdTime != null) 'createdTime': createdTime!.toIso8601String(),
        if (isLive != null) 'isLive': isLive,
        if (routeDetails != null) 'routeDetails': routeDetails,
        if (ring != null) 'ring': ring,
        if (altFloorMeters != null) 'altFloorMeters': altFloorMeters,
        if (altCeilMeters != null) 'altCeilMeters': altCeilMeters,
        if (startTime != null) 'startTime': startTime!.toIso8601String(),
        if (geoDetailsBytes != null) 'geoDetailsBytes': geoDetailsBytes,
        if (linePositions != null) 'linePositions': linePositions,
        if (sidc != null) 'sidc': sidc,
        if (prototypeExtensionsBytes != null)
          'prototypeExtensionsBytes': prototypeExtensionsBytes,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Entity && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Entity(id: $id, name: $name, disposition: ${disposition.name})';
}

sealed class EntityEvent {}

class EntityUpsert extends EntityEvent {
  EntityUpsert(this.entity);
  final Entity entity;
}

class EntityDelete extends EntityEvent {
  EntityDelete(this.entityId);
  final String entityId;
}
