import 'package:latlong2/latlong.dart';

class RecoveryReport {
  final int? id;
  final String? entityId;
  final String fromCallsign;
  final String bumperNumber;
  final String issue;
  final String recoveryType;
  final double latitude;
  final double longitude;
  final double? navigatorLatitude;
  final double? navigatorLongitude;
  final List<LatLng>? routeGeometry;
  final DateTime timestamp;
  final bool isOutgoing;
  final bool isRead;

  const RecoveryReport({
    this.id,
    this.entityId,
    required this.fromCallsign,
    required this.bumperNumber,
    required this.issue,
    required this.recoveryType,
    required this.latitude,
    required this.longitude,
    this.navigatorLatitude,
    this.navigatorLongitude,
    this.routeGeometry,
    required this.timestamp,
    this.isOutgoing = false,
    this.isRead = false,
  });

  bool get hasGeometry => routeGeometry != null && routeGeometry!.isNotEmpty;

  RecoveryReport copyWith({
    int? id,
    String? entityId,
    String? fromCallsign,
    String? bumperNumber,
    String? issue,
    String? recoveryType,
    double? latitude,
    double? longitude,
    double? navigatorLatitude,
    double? navigatorLongitude,
    List<LatLng>? routeGeometry,
    DateTime? timestamp,
    bool? isOutgoing,
    bool? isRead,
    bool clearNavigatorLocation = false,
  }) {
    return RecoveryReport(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      fromCallsign: fromCallsign ?? this.fromCallsign,
      bumperNumber: bumperNumber ?? this.bumperNumber,
      issue: issue ?? this.issue,
      recoveryType: recoveryType ?? this.recoveryType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      navigatorLatitude: clearNavigatorLocation
          ? null
          : (navigatorLatitude ?? this.navigatorLatitude),
      navigatorLongitude: clearNavigatorLocation
          ? null
          : (navigatorLongitude ?? this.navigatorLongitude),
      routeGeometry:
          clearNavigatorLocation ? null : (routeGeometry ?? this.routeGeometry),
      timestamp: timestamp ?? this.timestamp,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      isRead: isRead ?? this.isRead,
    );
  }
}
