/// Typed constants for SVG map icon asset paths.
///
/// Eliminates magic strings when referencing map icons. All paths are relative
/// to the main app's asset root.
class LatticeMapIcons {
  LatticeMapIcons._();

  static const String _base = 'openlayers/dist/icons';

  // ── Entity type icons ──

  static const String air = '$_base/air.svg';
  static const String bomber = '$_base/bomber.svg';
  static const String building = '$_base/building.svg';
  static const String fighter = '$_base/fighter.svg';
  static const String ground = '$_base/ground.svg';
  static const String helicopter = '$_base/helicopter.svg';
  static const String missile = '$_base/missile.svg';
  static const String person = '$_base/person.svg';
  static const String radar = '$_base/radar.svg';
  static const String satellite = '$_base/satellite.svg';
  static const String sea = '$_base/sea.svg';
  static const String sensor = '$_base/sensor.svg';
  static const String signal = '$_base/signal.svg';
  static const String submarine = '$_base/submarine.svg';
  static const String tank = '$_base/tank.svg';
  static const String uav = '$_base/uav.svg';
  static const String unknown = '$_base/unknown.svg';
  static const String vehicle = '$_base/vehicle.svg';
}
