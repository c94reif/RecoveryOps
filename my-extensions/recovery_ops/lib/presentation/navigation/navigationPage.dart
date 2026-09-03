import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:recovery_ops/core/di/injection.dart';
import 'package:recovery_ops/core/theme/appTheme.dart';
import 'package:recovery_ops/presentation/home/homeViewModel.dart';
import 'package:recovery_ops/presentation/navigation/navigationViewModel.dart';

class NavigationPage extends StatelessWidget {
  const NavigationPage({super.key});

  static const navBlue = Color(0xFF4A90D9);

  @override
  Widget build(BuildContext context) {
    final viewModel = getIt<NavigationViewModel>();

    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final report = viewModel.navigatingReport;

        if (report == null || viewModel.currentLocation == null) {
          return Center(
            child: Text(
              'Not currently navigating',
              style: TextStyle(color: Colors.white60, fontSize: 16),
            ),
          );
        }

        final destination = LatLng(report.latitude, report.longitude);
        final current = viewModel.currentLocation!;

        final bearing = calculateBearing(current, destination);
        final distance = const Distance(roundResult: false)
            .as(LengthUnit.Meter, current, destination);

        final distanceText = distance < 1000
            ? '${distance.round()} m'
            : '${(distance / 1000).toStringAsFixed(1)} km';

        final bearingText = '${bearing.round()}°';
        final cardinalText = cardinalDirection(bearing);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${report.bumperNumber} — ${report.recoveryType}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'From ${report.fromCallsign}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const Spacer(),
              Transform.rotate(
                angle: bearing * pi / 180,
                child: const Icon(
                  Icons.navigation,
                  size: 64,
                  color: navBlue,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.explore, size: 16, color: Colors.white60),
                  const SizedBox(width: 8),
                  Text(
                    '$bearingText $cardinalText',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.straighten, size: 16, color: Colors.white60),
                  const SizedBox(width: 8),
                  Text(
                    distanceText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    viewModel.stopNavigation();
                    final homeVm = getIt<HomeViewModel>();
                    homeVm.selectTab(1);
                  },
                  icon: const Icon(Icons.stop, size: 16),
                  label: const Text('Stop Navigation'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade800,
                    backgroundColor: const Color(0x26C62828),
                    side: BorderSide(color: Colors.red.shade800, width: 1),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitudeInRad;
    final lat2 = to.latitudeInRad;
    final dLng = to.longitudeInRad - from.longitudeInRad;

    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    final bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  String cardinalDirection(double bearing) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) / 45).floor() % 8;
    return directions[index];
  }
}
