import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';

class RoutePlannerExtension extends LatticeEdgeExtension {
  @override
  String get id => 'route_planner';
  @override
  String get name => 'Route Planner';
  @override
  String get description => 'Plan multi-point routes with distance calculation';
  @override
  IconData get icon => Icons.route;
  @override
  String? get iconAsset => 'assets/logo.png';
  @override
  ExtensionDisplayMode get defaultDisplayMode => ExtensionDisplayMode.panel;

  @override
  Widget build(ExtensionContext context) => _RoutePlannerUI(context: context);
}

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

class _Waypoint {
  final String markerId;
  final LatLng location;
  final String label;

  const _Waypoint({required this.markerId, required this.location, required this.label});

  Map<String, dynamic> toJson() => {
        'lat': location.latitude,
        'lng': location.longitude,
        'label': label,
      };
}

enum _RouteStatus { saved, sent, received }

class _SavedRoute {
  final List<Map<String, dynamic>> waypoints;
  final double totalDistance;
  final DateTime timestamp;
  final _RouteStatus status;
  final String? fromCallsign;
  final DeliveryReport? deliveryReport;

  _SavedRoute({
    required this.waypoints,
    required this.totalDistance,
    required this.timestamp,
    required this.status,
    this.fromCallsign,
    this.deliveryReport,
  });

  Map<String, dynamic> toJson() => {
        'waypoints': waypoints,
        'totalDistance': totalDistance,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'status': status.name,
        'fromCallsign': fromCallsign,
      };

  factory _SavedRoute.fromJson(Map<String, dynamic> json) => _SavedRoute(
        waypoints: (json['waypoints'] as List)
            .map((w) => Map<String, dynamic>.from(w as Map))
            .toList(),
        totalDistance: (json['totalDistance'] as num).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
        status: _RouteStatus.values.byName(json['status'] as String),
        fromCallsign: json['fromCallsign'] as String?,
      );
}

// ---------------------------------------------------------------------------
// UI
// ---------------------------------------------------------------------------

class _RoutePlannerUI extends StatefulWidget {
  final ExtensionContext context;
  const _RoutePlannerUI({required this.context});

  @override
  State<_RoutePlannerUI> createState() => _RoutePlannerUIState();
}

class _RoutePlannerUIState extends State<_RoutePlannerUI> {
  static const _maxWaypoints = 10;
  static const _polylineId = 'route_planner_route';
  static const _colors = [
    '#4CAF50', '#2196F3', '#FF9800', '#9C27B0', '#F44336',
    '#00BCD4', '#FFEB3B', '#E91E63', '#8BC34A', '#FF5722',
  ];

  final List<_Waypoint> _waypoints = [];
  final List<_SavedRoute> _routeHistory = [];
  bool _picking = false;
  String? _statusMessage;

  MapService get _map => widget.context.map;
  MessagingService get _messaging => widget.context.messaging;
  StorageService get _storage => widget.context.storage;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _messaging.markAllAsRead();
    _messaging.onMessageReceived.listen(_onMessageReceived);
  }

  void _onMessageReceived(IncomingMessage msg) {
    try {
      final data = jsonDecode(msg.payload) as Map<String, dynamic>;
      if (data['type'] != 'route') return;
      final points = (data['waypoints'] as List)
          .map((w) => Map<String, dynamic>.from(w as Map))
          .toList();
      if (mounted) {
        setState(() {
          _routeHistory.insert(
            0,
            _SavedRoute(
              waypoints: points,
              totalDistance: _totalDistanceFromJson(points),
              timestamp: msg.receivedAt,
              status: _RouteStatus.received,
              fromCallsign: msg.fromCallsign,
            ),
          );
        });
        _persistRoutes();
      }
    } catch (_) {}
  }

  Future<void> _loadRoutes() async {
    final raw = await _storage.read('routes');
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      setState(() {
        _routeHistory.addAll(
          list.map((e) => _SavedRoute.fromJson(e as Map<String, dynamic>)),
        );
      });
    } catch (_) {}
  }

  Future<void> _persistRoutes() async {
    await _storage.write(
      'routes',
      jsonEncode(_routeHistory.map((r) => r.toJson()).toList()),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    return Column(
      children: [
        _buildHeader(colors),
        Expanded(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              // Add waypoint button (inline, at top of list)
              _buildAddWaypointTile(colors),
              ..._buildWaypointTiles(colors),
              if (_waypoints.length >= 2) _buildSummaryCard(colors),
              const SizedBox(height: 12),
              // Save / Send row
              if (_waypoints.isNotEmpty) _buildSaveSendRow(colors),
              if (_statusMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _statusMessage!,
                  style: TextStyle(color: colors.success, fontSize: 11),
                ),
              ],
              // Route history
              if (_routeHistory.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'ROUTE HISTORY',
                  style: TextStyle(
                    color: colors.textLabel,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                for (final route in _routeHistory) _buildRouteHistoryCard(route, colors),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(LatticeColorScheme colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Icon(Icons.route, color: colors.accent, size: 24),
          const SizedBox(width: 10),
          Text('Route Planner',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('${_waypoints.length} / $_maxWaypoints',
              style: TextStyle(fontSize: 12, color: colors.textMuted)),
          if (_waypoints.isNotEmpty) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _clearRoute,
              child: Icon(Icons.delete_outline, size: 18, color: colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Add waypoint tile
  // ---------------------------------------------------------------------------

  Widget _buildAddWaypointTile(LatticeColorScheme colors) {
    final canAdd = _waypoints.length < _maxWaypoints && !_picking;
    return GestureDetector(
      onTap: canAdd ? _addWaypoint : null,
      child: Container(
        height: 48,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.borderActive, width: 1),
          color: colors.surface,
        ),
        child: Row(
          children: [
            if (_picking)
              SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent),
              )
            else
              Icon(Icons.add_location_alt, size: 16,
                  color: canAdd ? colors.accent : colors.textMuted),
            const SizedBox(width: 8),
            Text(
              _picking ? 'Picking location...' : 'Pick location on map',
              style: TextStyle(
                color: canAdd ? colors.accent : colors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Waypoint list
  // ---------------------------------------------------------------------------

  List<Widget> _buildWaypointTiles(LatticeColorScheme colors) {
    if (_waypoints.isEmpty) return [];

    final tiles = <Widget>[];
    for (int i = 0; i < _waypoints.length; i++) {
      final wp = _waypoints[i];
      final color = _parseColor(_colors[i % _colors.length]);

      tiles.add(ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: color,
          child: Text('${i + 1}',
              style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        title: Text(wp.label, style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          '${wp.location.latitude.toStringAsFixed(5)}, ${wp.location.longitude.toStringAsFixed(5)}',
          style: TextStyle(fontSize: 11, color: colors.textMuted),
        ),
        trailing: IconButton(
          icon: Icon(Icons.close, size: 18, color: colors.textMuted),
          onPressed: () => _removeWaypoint(i),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ));

      if (i < _waypoints.length - 1) {
        final dist = _haversineMeters(_waypoints[i].location, _waypoints[i + 1].location);
        tiles.add(Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Row(children: [
            Icon(Icons.arrow_downward, size: 14, color: colors.textMuted),
            const SizedBox(width: 6),
            Text(_formatDistance(dist),
                style: TextStyle(fontSize: 12, color: colors.accent)),
          ]),
        ));
      }
    }
    return tiles;
  }

  // ---------------------------------------------------------------------------
  // Route summary
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCard(LatticeColorScheme colors) {
    final total = _totalDistance();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.borderActive),
      ),
      child: Row(children: [
        Icon(Icons.summarize, size: 18, color: colors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Route Summary',
                style: TextStyle(fontSize: 11, color: colors.textMuted)),
            const SizedBox(height: 2),
            Text(
              '${_waypoints.length} waypoints  •  ${_formatDistance(total)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      ]),
    );
  }

  // ---------------------------------------------------------------------------
  // Save / Send row (field_report convention)
  // ---------------------------------------------------------------------------

  Widget _buildSaveSendRow(LatticeColorScheme colors) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.surface,
                side: BorderSide(color: colors.borderActive),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Save',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _waypoints.length >= 2 ? _onSend : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                disabledBackgroundColor: colors.borderActive,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Send',
                style: TextStyle(
                  color: colors.onAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Route history
  // ---------------------------------------------------------------------------

  Widget _buildRouteHistoryCard(_SavedRoute route, LatticeColorScheme colors) {
    final wpCount = route.waypoints.length;
    final timeStr =
        '${route.timestamp.hour.toString().padLeft(2, '0')}:'
        '${route.timestamp.minute.toString().padLeft(2, '0')}';

    final (Color badgeBg, Color badgeFg, String badgeText) = switch (route.status) {
      _RouteStatus.saved => (colors.borderActive, colors.textLabel, 'SAVED'),
      _RouteStatus.sent => (const Color(0xFF1A3A1A), const Color(0xFF66BB6A), 'SENT'),
      _RouteStatus.received => (const Color(0xFF1A1A3A), colors.accent, 'RECEIVED'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border, width: 1),
        color: colors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route, size: 14, color: colors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$wpCount waypoints  •  ${_formatDistance(route.totalDistance)}',
                  style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeFg, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time, size: 10, color: colors.inactive),
              const SizedBox(width: 2),
              Text(timeStr, style: TextStyle(color: colors.inactive, fontSize: 10)),
              if (route.status == _RouteStatus.received && route.fromCallsign != null) ...[
                const SizedBox(width: 8),
                Text('From: ${route.fromCallsign}',
                    style: TextStyle(color: colors.accent, fontSize: 10)),
              ],
              if (route.status == _RouteStatus.sent && route.deliveryReport != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${route.deliveryReport!.successCount}/${route.deliveryReport!.results.length} delivered',
                  style: TextStyle(color: colors.success, fontSize: 10),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: () => _loadSavedRoute(route),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.surfaceElevated,
                    side: BorderSide(color: colors.borderActive),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: Text('Load', style: TextStyle(color: colors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
              if (route.status == _RouteStatus.saved) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () => _sendSavedRoute(route),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text('Send', style: TextStyle(color: colors.onAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _addWaypoint() async {
    setState(() => _picking = true);
    try {
      final loc = await _map.pickLocation();
      if (loc == null || !mounted) return;

      final index = _waypoints.length + 1;
      final label = 'WP $index';
      final color = _colors[(_waypoints.length) % _colors.length];

      final markerId = await _map.addMarker(loc, label: label, color: color);
      setState(() {
        _waypoints.add(_Waypoint(markerId: markerId, location: loc, label: label));
      });
      await _updatePolyline();
      await _map.flyTo(loc);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _removeWaypoint(int index) async {
    final wp = _waypoints[index];
    await _map.removeMarker(wp.markerId);
    setState(() => _waypoints.removeAt(index));
    await _updatePolyline();
  }

  Future<void> _clearRoute() async {
    await _map.clearMarkers();
    await _map.clearPolylines();
    setState(() => _waypoints.clear());
  }

  Future<void> _updatePolyline() async {
    if (_waypoints.length < 2) {
      await _map.removePolyline(_polylineId);
      return;
    }
    await _map.addPolyline(
      _polylineId,
      _waypoints.map((w) => w.location).toList(),
      color: LatticeColorScheme.dark.accent.toHex(),
    );
  }

  void _onSave() {
    if (_waypoints.isEmpty) {
      setState(() => _statusMessage = 'Add at least one waypoint');
      return;
    }
    final waypointData = _waypoints.map((w) => w.toJson()).toList();
    setState(() {
      _routeHistory.insert(
        0,
        _SavedRoute(
          waypoints: waypointData,
          totalDistance: _totalDistance(),
          timestamp: DateTime.now(),
          status: _RouteStatus.saved,
        ),
      );
      _statusMessage = 'Route saved';
    });
    _persistRoutes();
    _clearRoute();
    setState(() {});
  }

  Future<void> _onSend() async {
    if (_waypoints.length < 2) {
      setState(() => _statusMessage = 'Need at least 2 waypoints to send');
      return;
    }
    final waypointData = _waypoints.map((w) => w.toJson()).toList();

    final recipients = await _messaging.pickRecipients();
    if (recipients == null || recipients.isEmpty) return;

    final payload = jsonEncode({
      'type': 'route',
      'waypoints': waypointData,
    });

    final report = await _messaging.sendToMultiple(
      recipients.map((p) => p.deviceId).toList(),
      payload,
    );

    setState(() {
      _routeHistory.insert(
        0,
        _SavedRoute(
          waypoints: waypointData,
          totalDistance: _totalDistance(),
          timestamp: DateTime.now(),
          status: _RouteStatus.sent,
          deliveryReport: report,
        ),
      );
      _statusMessage =
          'Sent to ${report.successCount}/${report.results.length} recipients';
    });
    _persistRoutes();
    _clearRoute();
    setState(() {});
  }

  Future<void> _sendSavedRoute(_SavedRoute saved) async {
    final recipients = await _messaging.pickRecipients();
    if (recipients == null || recipients.isEmpty) return;

    final payload = jsonEncode({
      'type': 'route',
      'waypoints': saved.waypoints,
    });

    final report = await _messaging.sendToMultiple(
      recipients.map((p) => p.deviceId).toList(),
      payload,
    );

    setState(() {
      final idx = _routeHistory.indexOf(saved);
      if (idx >= 0) {
        _routeHistory[idx] = _SavedRoute(
          waypoints: saved.waypoints,
          totalDistance: saved.totalDistance,
          timestamp: saved.timestamp,
          status: _RouteStatus.sent,
          deliveryReport: report,
        );
      }
      _statusMessage =
          'Sent to ${report.successCount}/${report.results.length} recipients';
    });
    _persistRoutes();
  }

  Future<void> _loadSavedRoute(_SavedRoute route) async {
    await _clearRoute();

    for (int i = 0; i < route.waypoints.length; i++) {
      final wp = route.waypoints[i];
      final loc = LatLng(
        (wp['lat'] as num).toDouble(),
        (wp['lng'] as num).toDouble(),
      );
      final label = wp['label'] as String? ?? 'WP ${i + 1}';
      final color = _colors[i % _colors.length];
      final markerId = await _map.addMarker(loc, label: label, color: color);
      _waypoints.add(_Waypoint(markerId: markerId, location: loc, label: label));
    }
    setState(() => _statusMessage = 'Route loaded');
    await _updatePolyline();

    if (_waypoints.isNotEmpty) {
      await _map.flyTo(_waypoints.first.location);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  double _totalDistance() {
    double total = 0;
    for (int i = 0; i < _waypoints.length - 1; i++) {
      total += _haversineMeters(_waypoints[i].location, _waypoints[i + 1].location);
    }
    return total;
  }

  static Color _parseColor(String hex) {
    return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
  }
}

// ---------------------------------------------------------------------------
// Haversine distance
// ---------------------------------------------------------------------------

double _haversineMeters(LatLng a, LatLng b) {
  const r = 6371000.0;
  final dLat = _toRad(b.latitude - a.latitude);
  final dLon = _toRad(b.longitude - a.longitude);
  final lat1 = _toRad(a.latitude);
  final lat2 = _toRad(b.latitude);
  final h = _hav(dLat) + math.cos(lat1) * math.cos(lat2) * _hav(dLon);
  return 2 * r * math.asin(math.sqrt(h));
}

double _toRad(double deg) => deg * math.pi / 180;
double _hav(double x) => (1 - math.cos(x)) / 2;

double _totalDistanceFromJson(List<Map<String, dynamic>> waypoints) {
  double total = 0;
  for (int i = 0; i < waypoints.length - 1; i++) {
    final a = LatLng(
      (waypoints[i]['lat'] as num).toDouble(),
      (waypoints[i]['lng'] as num).toDouble(),
    );
    final b = LatLng(
      (waypoints[i + 1]['lat'] as num).toDouble(),
      (waypoints[i + 1]['lng'] as num).toDouble(),
    );
    total += _haversineMeters(a, b);
  }
  return total;
}

String _formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}
