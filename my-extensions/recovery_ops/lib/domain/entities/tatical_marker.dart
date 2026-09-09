import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class TacticalMarker {
  final LatLng position;
  final String callsign;
  final String uid;
  final IconData icon;
  final Color color;
  final String? issue;

  const TacticalMarker({
    required this.position,
    required this.callsign,
    required this.uid,
    this.icon = Icons.location_on,
    this.color = const Color(0xFF4A7820),
    this.issue,
  });
}
