import 'dart:typed_data';

// ---------------------------------------------------------------------------
// Device Service — raw hardware I/O
// ---------------------------------------------------------------------------

/// Transport-level events from the USB serial bridge.
enum UsbSerialEvent {
  /// A USB serial device was attached.
  deviceAttached,

  /// A USB serial device was detached.
  deviceDetached,

  /// USB permission was granted by the user.
  permissionGranted,

  /// USB permission was denied by the user.
  permissionDenied,
}

/// Generic raw byte I/O over USB serial.
///
/// The host owns the MethodChannel and Kotlin bridge (generic USB serial).
/// The plugin drives the protocol (SLP — hardware-specific).
///
/// Access via [DeviceService.usbSerial] on [ExtensionContext.device].
abstract class UsbSerialService {
  /// Stream of raw bytes received from the serial port.
  Stream<Uint8List> get rxBytes;

  /// Stream of transport-level events (attach, detach, permission).
  Stream<UsbSerialEvent> get events;

  /// Open USB serial connection.
  ///
  /// Returns a JSON result string from the native bridge.
  Future<String> connect({
    int baudRate = 9600,
    int dataBits = 8,
    int stopBits = 1,
    int parity = 0,
  });

  /// Close the USB serial connection.
  Future<void> disconnect();

  /// Write raw bytes to the serial port.
  Future<void> write(Uint8List bytes);

  /// List detected USB serial devices as a JSON string (for diagnostics).
  Future<String> listDevices();

  /// Release resources.
  void dispose();
}

/// Access to hardware device capabilities.
///
/// Access via [ExtensionContext.device].
abstract class DeviceService {
  /// Raw USB serial I/O. The plugin drives the protocol; the host provides
  /// only byte-level transport.
  UsbSerialService get usbSerial;
}

// ---------------------------------------------------------------------------
// Peripherals Service — sensor event buses
// ---------------------------------------------------------------------------

/// Target data published by a laser rangefinder (LRF) peripheral.
///
/// Used by [RangeFinderService] to bridge the plugin's target events to host
/// widgets ([CffCreateForm], [LaserMarkerMixin]).
class RangeFinderTarget {
  const RangeFinderTarget({
    required this.latDeg,
    required this.lonDeg,
    required this.altMeters,
    required this.sourceId,
    this.mgrs,
    this.targetLocMethod,
  });

  /// Target latitude (WGS-84, degrees).
  final double latDeg;

  /// Target longitude (WGS-84, degrees).
  final double lonDeg;

  /// Target altitude (meters, MSL).
  final double altMeters;

  /// Pre-computed MGRS string (optional; widget will compute if absent).
  final String? mgrs;

  /// Identifies the plugin that published this target (e.g. 'my-lrf-plugin').
  final String sourceId;

  /// Target location method string (e.g. 'laserGrid').
  final String? targetLocMethod;

  @override
  String toString() =>
      'RangeFinderTarget(lat=$latDeg, lon=$lonDeg, alt=$altMeters, '
      'mgrs=$mgrs, source=$sourceId)';
}

/// One-way event bus for range-finder target data.
///
/// Plugins call [publishTarget] when the range finder reports a target.
/// Host widgets ([CffCreateForm], [LaserMarkerMixin]) subscribe via [targetStream].
///
/// Access via [PeripheralsService.rangeFinder] on [ExtensionContext.peripherals].
abstract class RangeFinderService {
  /// Plugin calls this when the range finder reports a target.
  void publishTarget(RangeFinderTarget target);

  /// Host widgets listen on this stream for incoming target data.
  Stream<RangeFinderTarget> get targetStream;
}

/// Access to peripheral sensor capabilities.
///
/// Access via [ExtensionContext.peripherals].
abstract class PeripheralsService {
  /// Range-finder event bus. Plugins publish; host widgets subscribe.
  RangeFinderService get rangeFinder;
}
