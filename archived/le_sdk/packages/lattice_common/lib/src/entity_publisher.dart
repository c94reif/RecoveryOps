import 'entity.dart';

/// Request to publish (create) an entity.
class PublishEntityRequest {
  const PublishEntityRequest({
    required this.lat,
    required this.lon,
    this.name,
    this.disposition = Disposition.hostile,
    this.environment = 'land',
    this.sidc,
  });

  final double lat;
  final double lon;
  final String? name;
  final Disposition disposition;
  final String environment;

  /// MIL-STD-2525C SIDC string. When non-null, set directly on
  /// `entity.symbology.milStd2525C.sidc`. When null, a fallback is
  /// derived from [disposition] + [environment].
  final String? sidc;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lon': lon,
        if (name != null) 'name': name,
        'disposition': disposition.name,
        'environment': environment,
        if (sidc != null) 'sidc': sidc,
      };
}

/// Result of publishing an entity.
class PublishEntityResult {
  const PublishEntityResult({
    required this.entityId,
    required this.displayName,
  });

  final String entityId;
  final String displayName;
}

/// Abstract interface for publishing (creating/updating) entities.
abstract class EntityPublisher {
  Future<PublishEntityResult> publishEntity(PublishEntityRequest request);

  /// Create or update an entity using a full [Entity] object.
  /// Returns the entity ID assigned by the backend.
  Future<String> upsertEntity(Entity entity);

  /// Delete an entity by ID.
  ///
  /// For the live backend this publishes the entity with `isLive: false`,
  /// which triggers a DELETE event in Entity Manager. For the mock backend
  /// it removes the entity from the world directly.
  Future<void> deleteEntity(String entityId);
}
