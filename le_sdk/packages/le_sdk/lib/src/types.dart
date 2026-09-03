/// Display mode for an extension's content.
enum ExtensionDisplayMode { panel, overlay }

/// Built-in icon types for map markers.
enum MarkerIcon {
  air, ground, sea, helicopter, uav, fighter, bomber, tank,
  missile, submarine, satellite, sensor, radar, person,
  vehicle, building, signal, unknown;
}

/// Military disposition for icon marker coloring.
enum MarkerDisposition {
  hostile, friendly, neutral, unknown;
}

/// A geographic coordinate.
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  factory LatLng.fromJson(Map<String, dynamic> json) =>
      LatLng(json['latitude'] as double, json['longitude'] as double);

  @override
  bool operator ==(Object other) =>
      other is LatLng &&
      latitude == other.latitude &&
      longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}

/// A marker placed on the map by an extension.
class MapMarker {
  final String id;
  final double latitude;
  final double longitude;
  final String? label;
  final String? color;
  final MarkerIcon? icon;
  final MarkerDisposition? disposition;

  const MapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.label,
    this.color,
    this.icon,
    this.disposition,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        if (label != null) 'label': label,
        if (color != null) 'color': color,
        if (icon != null) 'icon': icon!.name,
        if (disposition != null) 'disposition': disposition!.name,
      };

  factory MapMarker.fromJson(Map<String, dynamic> json) => MapMarker(
        id: json['id'] as String,
        latitude: (json['latitude'] ?? json['lat']) as double,
        longitude: (json['longitude'] ?? json['lon']) as double,
        label: json['label'] as String?,
        color: json['color'] as String?,
        icon: json['icon'] != null
            ? MarkerIcon.values.byName(json['icon'] as String)
            : null,
        disposition: json['disposition'] != null
            ? MarkerDisposition.values.byName(json['disposition'] as String)
            : null,
      );
}

/// Information about the host environment.
class HostInfo {
  final String host;
  final String version;
  final String extensionId;

  /// The operator's callsign on this device, or null if not set.
  final String? callsign;

  const HostInfo({
    required this.host,
    required this.version,
    required this.extensionId,
    this.callsign,
  });

  Map<String, dynamic> toJson() => {
        'host': host,
        'version': version,
        'extensionId': extensionId,
        if (callsign != null) 'callsign': callsign,
      };

  factory HostInfo.fromJson(Map<String, dynamic> json) => HostInfo(
        host: json['host'] as String,
        version: json['version'] as String,
        extensionId: (json['extensionId'] ?? json['pluginId']) as String,
        callsign: json['callsign'] as String?,
      );
}

/// A point in logical screen pixel coordinates.
class ScreenPoint {
  final double x;
  final double y;
  const ScreenPoint(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory ScreenPoint.fromJson(Map<String, dynamic> j) => ScreenPoint(
        (j['x'] as num).toDouble(),
        (j['y'] as num).toDouble(),
      );
}
