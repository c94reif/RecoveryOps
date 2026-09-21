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
