import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';

/// "CASEVAC 9-Line" plugin — Dart implementation.
///
/// Provides a form for submitting 9-Line MEDEVAC/CASEVAC requests following
/// the standard US military casualty evacuation request format.
class CasevacReportPlugin extends LatticeEdgeExtension {
  @override
  String get id => 'casevac_report';

  @override
  String get name => 'CASEVAC 9-Line';

  @override
  String get description =>
      'Submit 9-Line CASEVAC/MEDEVAC requests with full tactical detail';

  @override
  IconData get icon => Icons.emergency;

  @override
  String? get iconAsset => 'assets/logo.png';

  @override
  ExtensionDisplayMode get defaultDisplayMode => ExtensionDisplayMode.panel;

  @override
  Widget build(ExtensionContext context) => _CasevacForm(context: context);
}

enum _ReportStatus { saved, sent, received }

class _SavedReport {
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final _ReportStatus status;
  final String? fromCallsign;
  final DeliveryReport? deliveryReport;

  _SavedReport({
    required this.data,
    required this.timestamp,
    required this.status,
    this.fromCallsign,
    this.deliveryReport,
  });

  Map<String, dynamic> toJson() => {
        'data': data,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'status': status.name,
        'fromCallsign': fromCallsign,
      };

  factory _SavedReport.fromJson(Map<String, dynamic> json) => _SavedReport(
        data: Map<String, dynamic>.from(json['data'] as Map),
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
        status: _ReportStatus.values.byName(json['status'] as String),
        fromCallsign: json['fromCallsign'] as String?,
      );
}

enum _IncidentType { tic, ied, accident, training, other }

enum _SpecialEquipment { none, hoist, extraction, ventilator }

enum _SecurityLevel { noEnemy, possibleEnemy, enemyInArea, armedEscort }

enum _MarkingMethod { panels, pyrotechnic, smoke, none, irStrobe }

enum _Nationality { usMilitary, usCivilian, coalition, epw, civilian }

enum _TriageStatus { immediate, delayed, minimal, expectant }

class _CasevacForm extends StatefulWidget {
  final ExtensionContext context;

  const _CasevacForm({required this.context});

  @override
  State<_CasevacForm> createState() => _CasevacFormState();
}

class _CasevacFormState extends State<_CasevacForm> {
  final _scrollController = ScrollController();
  final _callsignFocusNode = FocusNode();

  // Validation error states
  bool _callsignError = false;
  bool _locationError = false;
  bool _patientError = false;

  // Header
  final _callsignController = TextEditingController();
  final _dtgController = TextEditingController();
  _IncidentType _incidentType = _IncidentType.tic;

  // Line 1 — Location
  LatLng? _pickupLocation;
  final _gridRefController = TextEditingController();

  // Line 2 — Frequency & Callsign
  final _frequencyController = TextEditingController();
  final _contactCallsignController = TextEditingController();

  // Line 3 — Patients by Precedence
  final _urgentSurgicalController = TextEditingController(text: '0');
  final _urgentController = TextEditingController(text: '0');
  final _priorityController = TextEditingController(text: '0');
  final _routineController = TextEditingController(text: '0');

  // Line 4 — Special Equipment
  _SpecialEquipment _specialEquipment = _SpecialEquipment.none;

  // Line 5 — Patients by Type
  final _litterController = TextEditingController(text: '0');
  final _ambulatoryController = TextEditingController(text: '0');

  // Line 6 — Security at Pickup Site
  _SecurityLevel _securityLevel = _SecurityLevel.noEnemy;

  // Line 7 — Marking Method
  _MarkingMethod _markingMethod = _MarkingMethod.panels;

  // Line 8 — Patient Nationality & Status
  _Nationality _nationality = _Nationality.usMilitary;
  _TriageStatus _triageStatus = _TriageStatus.immediate;

  // Line 9 — Terrain & Hazards
  bool _nbcContamination = false;
  final _terrainController = TextEditingController();

  // Footer
  String? _statusMessage;
  final _savedReports = <_SavedReport>[];
  final _expandedReports = <int>{};
  bool _micListening = false;

  @override
  void initState() {
    super.initState();
    _dtgController.text = _formatDtg(DateTime.now());

    widget.context.messaging.markAllAsRead();

    widget.context.messaging.onMessageReceived.listen((msg) {
      final data = jsonDecode(msg.payload);
      if (data['type'] == 'casevac_9line') {
        setState(() {
          _savedReports.insert(
            0,
            _SavedReport(
              data: Map<String, dynamic>.from(data['data'] as Map),
              timestamp: msg.receivedAt,
              status: _ReportStatus.received,
              fromCallsign: msg.fromCallsign,
            ),
          );
        });
        _persistReports();
      }
    });

    _loadReports();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _callsignFocusNode.dispose();
    _callsignController.dispose();
    _dtgController.dispose();
    _gridRefController.dispose();
    _frequencyController.dispose();
    _contactCallsignController.dispose();
    _urgentSurgicalController.dispose();
    _urgentController.dispose();
    _priorityController.dispose();
    _routineController.dispose();
    _litterController.dispose();
    _ambulatoryController.dispose();
    _terrainController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    final raw = await widget.context.storage.read('reports');
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      setState(() {
        _savedReports.addAll(
          list.map((e) => _SavedReport.fromJson(e as Map<String, dynamic>)),
        );
      });
    } catch (_) {}
  }

  Future<void> _persistReports() async {
    await widget.context.storage.write(
      'reports',
      jsonEncode(_savedReports.map((r) => r.toJson()).toList()),
    );
  }

  String _formatDtg(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    final month = months[dt.month - 1];
    final year = dt.year.toString().substring(2);
    return '$day$hour${min}Z $month $year';
  }

  String _toMgrs(LatLng loc) {
    return _latLngToMgrs(loc.latitude, loc.longitude);
  }

  /// Convert latitude/longitude (WGS-84) to an MGRS coordinate string.
  static String _latLngToMgrs(double lat, double lng) {
    // Clamp to UTM valid range
    if (lat < -80 || lat > 84) return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

    const a = 6378137.0; // WGS-84 semi-major axis
    const f = 1 / 298.257223563;
    const k0 = 0.9996;
    final e = math.sqrt(2 * f - f * f);
    final e2 = e * e;
    final ep2 = e2 / (1 - e2);

    final latRad = lat * math.pi / 180;
    var lngNorm = ((lng + 180) % 360) - 180;

    // UTM zone
    var zone = ((lngNorm + 180) / 6).floor() + 1;

    // Norway/Svalbard exceptions
    if (lat >= 56 && lat < 64 && lngNorm >= 3 && lngNorm < 12) zone = 32;
    if (lat >= 72 && lat < 84) {
      if (lngNorm >= 0 && lngNorm < 9) {
        zone = 31;
      } else if (lngNorm >= 9 && lngNorm < 21) {
        zone = 33;
      } else if (lngNorm >= 21 && lngNorm < 33) {
        zone = 35;
      } else if (lngNorm >= 33 && lngNorm < 42) {
        zone = 37;
      }
    }

    final centralMeridian = (zone - 1) * 6 - 180 + 3;
    final dlng = (lngNorm - centralMeridian) * math.pi / 180;

    final sinLat = math.sin(latRad);
    final cosLat = math.cos(latRad);
    final tanLat = math.tan(latRad);
    final n = a / math.sqrt(1 - e2 * sinLat * sinLat);
    final t = tanLat * tanLat;
    final c = ep2 * cosLat * cosLat;

    final aa = cosLat * dlng;
    final m = a * ((1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256) * latRad
        - (3 * e2 / 8 + 3 * e2 * e2 / 32 + 45 * e2 * e2 * e2 / 1024) * math.sin(2 * latRad)
        + (15 * e2 * e2 / 256 + 45 * e2 * e2 * e2 / 1024) * math.sin(4 * latRad)
        - (35 * e2 * e2 * e2 / 3072) * math.sin(6 * latRad));

    var easting = k0 * n * (aa + (1 - t + c) * aa * aa * aa / 6
        + (5 - 18 * t + t * t + 72 * c - 58 * ep2) * aa * aa * aa * aa * aa / 120) + 500000;

    var northing = k0 * (m + n * tanLat * (aa * aa / 2
        + (5 - t + 9 * c + 4 * c * c) * aa * aa * aa * aa / 24
        + (61 - 58 * t + t * t + 600 * c - 330 * ep2) * aa * aa * aa * aa * aa * aa / 720));

    if (lat < 0) northing += 10000000;

    // Latitude band letter
    const bandLetters = 'CDEFGHJKLMNPQRSTUVWX';
    final bandIdx = lat == 84 ? 19 : ((lat + 80) / 8).floor();
    final bandLetter = bandLetters[bandIdx.clamp(0, 19)];

    // 100km square column letter
    const colLetters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    final col100k = ((easting / 100000).floor()) % 24;
    final setNumber = ((zone - 1) % 6);
    final colIdx = (setNumber * 8 + col100k - 1) % 24;
    final colLetter = colLetters[colIdx.clamp(0, 23)];

    // 100km square row letter
    const rowLetters = 'ABCDEFGHJKLMNPQRSTUV';
    final rowSet = (zone - 1) % 2 == 0 ? 0 : 5;
    final rowIdx = ((northing / 100000).floor() + rowSet) % 20;
    final rowLetter = rowLetters[rowIdx.clamp(0, 19)];

    // 5-digit easting and northing within the 100km square
    final e5 = ((easting % 100000) / 1).round().toString().padLeft(5, '0').substring(0, 5);
    final n5 = ((northing % 100000) / 1).round().toString().padLeft(5, '0').substring(0, 5);

    return '$zone$bandLetter $colLetter$rowLetter $e5 $n5';
  }

  Future<void> _dictateToField(TextEditingController controller) async {
    if (_micListening) return;
    setState(() => _micListening = true);
    try {
      final text = await widget.context.speech.dictate();
      if (text != null && text.isNotEmpty && mounted) {
        final existing = controller.text;
        controller.text = existing.isEmpty ? text : '$existing $text';
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      }
    } finally {
      if (mounted) setState(() => _micListening = false);
    }
  }

  Future<void> _pickLocation() async {
    final location = await widget.context.map.pickLocation();
    if (location != null) {
      setState(() {
        _pickupLocation = location;
        _gridRefController.text = _toMgrs(location);
        _locationError = false;
      });
      final callsign = _callsignController.text.trim().isNotEmpty
          ? _callsignController.text.trim()
          : 'CASEVAC';
      await widget.context.map.addMarker(
        location,
        label: '\u2720 $callsign',
      );
    }
  }

  Map<String, dynamic> _collectFormData() {
    return {
      'callsign': _callsignController.text.trim(),
      'dtg': _dtgController.text.trim(),
      'incidentType': _incidentType.name,
      'pickupLat': _pickupLocation?.latitude,
      'pickupLng': _pickupLocation?.longitude,
      'gridRef': _gridRefController.text.trim(),
      'frequency': _frequencyController.text.trim(),
      'contactCallsign': _contactCallsignController.text.trim(),
      'urgentSurgical': int.tryParse(_urgentSurgicalController.text) ?? 0,
      'urgent': int.tryParse(_urgentController.text) ?? 0,
      'priority': int.tryParse(_priorityController.text) ?? 0,
      'routine': int.tryParse(_routineController.text) ?? 0,
      'specialEquipment': _specialEquipment.name,
      'litter': int.tryParse(_litterController.text) ?? 0,
      'ambulatory': int.tryParse(_ambulatoryController.text) ?? 0,
      'securityLevel': _securityLevel.name,
      'markingMethod': _markingMethod.name,
      'nationality': _nationality.name,
      'triageStatus': _triageStatus.name,
      'nbcContamination': _nbcContamination,
      'terrain': _terrainController.text.trim(),
    };
  }

  bool _validateRequired() {
    bool valid = true;
    bool callsignErr = false;
    bool locationErr = false;
    bool patientErr = false;

    if (_callsignController.text.trim().isEmpty) {
      callsignErr = true;
      valid = false;
    }

    if (_pickupLocation == null) {
      locationErr = true;
      valid = false;
    }

    final totalPatients = (int.tryParse(_urgentSurgicalController.text) ?? 0) +
        (int.tryParse(_urgentController.text) ?? 0) +
        (int.tryParse(_priorityController.text) ?? 0) +
        (int.tryParse(_routineController.text) ?? 0);
    if (totalPatients == 0) {
      patientErr = true;
      valid = false;
    }

    setState(() {
      _callsignError = callsignErr;
      _locationError = locationErr;
      _patientError = patientErr;
    });

    if (!valid) {
      // Scroll to first error
      _scrollController.animateTo(
        callsignErr ? 0 : locationErr ? 200 : 400,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
      if (callsignErr) {
        _callsignFocusNode.requestFocus();
      }
    }

    return valid;
  }

  void _resetForm() {
    _callsignController.clear();
    _dtgController.text = _formatDtg(DateTime.now());
    _incidentType = _IncidentType.tic;
    _pickupLocation = null;
    _gridRefController.clear();
    _frequencyController.clear();
    _contactCallsignController.clear();
    _urgentSurgicalController.text = '0';
    _urgentController.text = '0';
    _priorityController.text = '0';
    _routineController.text = '0';
    _specialEquipment = _SpecialEquipment.none;
    _litterController.text = '0';
    _ambulatoryController.text = '0';
    _securityLevel = _SecurityLevel.noEnemy;
    _markingMethod = _MarkingMethod.panels;
    _nationality = _Nationality.usMilitary;
    _triageStatus = _TriageStatus.immediate;
    _nbcContamination = false;
    _terrainController.clear();
    _statusMessage = null;
    _callsignError = false;
    _locationError = false;
    _patientError = false;
  }

  void _onSave() {
    if (!_validateRequired()) return;
    final reportData = _collectFormData();
    setState(() {
      _savedReports.insert(
        0,
        _SavedReport(
          data: reportData,
          timestamp: DateTime.now(),
          status: _ReportStatus.saved,
        ),
      );
      _statusMessage = 'Report saved';
    });
    _persistReports();
    _resetForm();
    setState(() {});
  }

  Future<void> _onSend() async {
    if (!_validateRequired()) return;
    final reportData = _collectFormData();
    final recipients = await widget.context.messaging.pickRecipients();
    if (recipients == null) return;

    final payload = jsonEncode({
      'type': 'casevac_9line',
      'data': reportData,
    });

    final report = await widget.context.messaging.sendToMultiple(
      recipients.map((p) => p.deviceId).toList(),
      payload,
    );

    setState(() {
      _savedReports.insert(
        0,
        _SavedReport(
          data: reportData,
          timestamp: DateTime.now(),
          status: _ReportStatus.sent,
          deliveryReport: report,
        ),
      );
      _statusMessage =
          'Sent to ${report.successCount}/${report.results.length} recipients';
    });
    _persistReports();
    _resetForm();
    setState(() {});
  }

  Future<void> _sendSavedReport(_SavedReport saved) async {
    final recipients = await widget.context.messaging.pickRecipients();
    if (recipients == null) return;

    final payload = jsonEncode({
      'type': 'casevac_9line',
      'data': saved.data,
    });

    final report = await widget.context.messaging.sendToMultiple(
      recipients.map((p) => p.deviceId).toList(),
      payload,
    );

    setState(() {
      final idx = _savedReports.indexOf(saved);
      if (idx >= 0) {
        _savedReports[idx] = _SavedReport(
          data: saved.data,
          timestamp: saved.timestamp,
          status: _ReportStatus.sent,
          deliveryReport: report,
        );
      }
      _statusMessage =
          'Sent to ${report.successCount}/${report.results.length} recipients';
    });
    _persistReports();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    return ListView(
      controller: _scrollController,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // ── HEADER ──
        const LatticeSectionHeader(title:'REPORT HEADER'),
        const SizedBox(height: 8),

        const LatticeSectionLabel('CALLSIGN / UNIT', isRequired: true),
        const SizedBox(height: 4),
        TextField(
          controller: _callsignController,
          focusNode: _callsignFocusNode,
          style: TextStyle(color: context.lattice.colors.textPrimary, fontSize: 13),
          decoration: latticeInputDecoration(context.lattice.colors, hint: 'e.g. WARRIOR 6', hasError: _callsignError),
          onChanged: (_) {
            if (_callsignError) setState(() => _callsignError = false);
          },
        ),
        if (_callsignError) ...[
          const SizedBox(height: 4),
          Text(
            'Callsign / Unit is required',
            style: TextStyle(color: colors.error, fontSize: 11),
          ),
        ],
        const SizedBox(height: 10),

        const LatticeSectionLabel('Date-Time Group (DTG)'),
        const SizedBox(height: 4),
        TextField(
          controller: _dtgController,
          style: TextStyle(color: context.lattice.colors.textPrimary, fontSize: 13),
          decoration: latticeInputDecoration(context.lattice.colors, hint: 'DDHHMMz MON YY'),
        ),
        const SizedBox(height: 10),

        const LatticeSectionLabel('Incident Type'),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final t in _IncidentType.values) ...[
              if (t != _IncidentType.tic) const SizedBox(width: 6),
              Expanded(
                child: _ToggleButton(
                  label: _incidentLabel(t),
                  isSelected: _incidentType == t,
                  onTap: () => setState(() => _incidentType = t),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // ── LINE 1 — LOCATION ──
        const LatticeSectionHeader(title:'LINE 1 — LOCATION'),
        const SizedBox(height: 8),

        const LatticeSectionLabel('PICKUP LOCATION', isRequired: true),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            _pickLocation();
            if (_locationError) setState(() => _locationError = false);
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _locationError
                      ? colors.error
                      : colors.borderActive,
                  width: 1,
                ),
                color: colors.surface,
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on,
                      size: 16, color: colors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pickupLocation != null
                          ? '${_pickupLocation!.latitude.toStringAsFixed(6)}, ${_pickupLocation!.longitude.toStringAsFixed(6)}'
                          : 'Pick location on map',
                      style: TextStyle(
                        color: _pickupLocation != null
                            ? colors.textPrimary
                            : colors.inactive,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (_pickupLocation != null)
                    IconButton(
                      icon: Icon(Icons.close,
                          size: 14, color: colors.inactive),
                      onPressed: () => setState(() {
                        _pickupLocation = null;
                        _gridRefController.clear();
                      }),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_locationError) ...[
          const SizedBox(height: 4),
          Text(
            'Pickup location is required',
            style: TextStyle(color: colors.error, fontSize: 11),
          ),
        ],
        const SizedBox(height: 8),

        const LatticeSectionLabel('Grid Reference (MGRS)'),
        const SizedBox(height: 4),
        TextField(
          controller: _gridRefController,
          style: TextStyle(color: context.lattice.colors.textPrimary, fontSize: 13),
          decoration: latticeInputDecoration(context.lattice.colors, hint: 'e.g. 17S QV 23480 06470'),
        ),
        const SizedBox(height: 16),

        // ── LINE 2 — FREQUENCY & CALLSIGN ──
        const LatticeSectionHeader(title:'LINE 2 — FREQUENCY & CALLSIGN'),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LatticeSectionLabel('Radio Frequency'),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _frequencyController,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: latticeInputDecoration(context.lattice.colors, hint: 'e.g. 35.500 FM'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LatticeSectionLabel('Contact Callsign'),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _contactCallsignController,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: latticeInputDecoration(context.lattice.colors, hint: 'e.g. DUSTOFF 7-2'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── LINE 3 — PATIENTS BY PRECEDENCE ──
        const LatticeSectionHeader(title:'LINE 3 — PATIENTS BY PRECEDENCE'),
        const SizedBox(height: 8),

        const LatticeSectionLabel('PATIENT COUNT', isRequired: true),
        const SizedBox(height: 4),

        Row(
          children: [
            Expanded(
              child: _buildNumberField(
                  'Urgent Surg', _urgentSurgicalController,
                  onChanged: (_) {
                    if (_patientError) setState(() => _patientError = false);
                  }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildNumberField('Urgent', _urgentController,
                  onChanged: (_) {
                    if (_patientError) setState(() => _patientError = false);
                  }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildNumberField('Priority', _priorityController,
                  onChanged: (_) {
                    if (_patientError) setState(() => _patientError = false);
                  }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildNumberField('Routine', _routineController,
                  onChanged: (_) {
                    if (_patientError) setState(() => _patientError = false);
                  }),
            ),
          ],
        ),
        if (_patientError) ...[
          const SizedBox(height: 4),
          Text(
            'At least one patient is required',
            style: TextStyle(color: colors.error, fontSize: 11),
          ),
        ],
        const SizedBox(height: 16),

        // ── LINE 4 — SPECIAL EQUIPMENT ──
        const LatticeSectionHeader(title:'LINE 4 — SPECIAL EQUIPMENT'),
        const SizedBox(height: 8),

        Row(
          children: [
            for (final e in _SpecialEquipment.values) ...[
              if (e != _SpecialEquipment.none) const SizedBox(width: 6),
              Expanded(
                child: _ToggleButton(
                  label: _equipmentLabel(e),
                  isSelected: _specialEquipment == e,
                  onTap: () => setState(() => _specialEquipment = e),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // ── LINE 5 — PATIENTS BY TYPE ──
        const LatticeSectionHeader(title:'LINE 5 — PATIENTS BY TYPE'),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildNumberField('Litter', _litterController),
            ),
            const SizedBox(width: 8),
            Expanded(
              child:
                  _buildNumberField('Ambulatory', _ambulatoryController),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── LINE 6 — SECURITY AT PICKUP SITE ──
        const LatticeSectionHeader(title:'LINE 6 — SECURITY AT PICKUP SITE'),
        const SizedBox(height: 8),

        Column(
          children: [
            for (final s in _SecurityLevel.values) ...[
              if (s != _SecurityLevel.noEnemy) const SizedBox(height: 6),
              _SecurityButton(
                level: s,
                isSelected: _securityLevel == s,
                onTap: () => setState(() => _securityLevel = s),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // ── LINE 7 — MARKING METHOD ──
        const LatticeSectionHeader(title:'LINE 7 — MARKING METHOD'),
        const SizedBox(height: 8),

        Row(
          children: [
            for (final m in _MarkingMethod.values) ...[
              if (m != _MarkingMethod.panels) const SizedBox(width: 6),
              Expanded(
                child: _ToggleButton(
                  label: _markingLabel(m),
                  isSelected: _markingMethod == m,
                  onTap: () => setState(() => _markingMethod = m),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // ── LINE 8 — PATIENT NATIONALITY & STATUS ──
        const LatticeSectionHeader(title:'LINE 8 — NATIONALITY & STATUS'),
        const SizedBox(height: 8),

        const LatticeSectionLabel('Nationality'),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final n in _Nationality.values) ...[
              if (n != _Nationality.usMilitary) const SizedBox(width: 6),
              Expanded(
                child: _ToggleButton(
                  label: _nationalityLabel(n),
                  isSelected: _nationality == n,
                  onTap: () => setState(() => _nationality = n),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        const LatticeSectionLabel('Triage Status'),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final t in _TriageStatus.values) ...[
              if (t != _TriageStatus.immediate) const SizedBox(width: 6),
              Expanded(
                child: _TriageButton(
                  status: t,
                  isSelected: _triageStatus == t,
                  onTap: () => setState(() => _triageStatus = t),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // ── LINE 9 — TERRAIN & HAZARDS ──
        const LatticeSectionHeader(title:'LINE 9 — TERRAIN & HAZARDS'),
        const SizedBox(height: 8),

        _buildToggleRow(
          'NBC Contamination',
          _nbcContamination,
          (v) => setState(() => _nbcContamination = v),
        ),
        const SizedBox(height: 8),

        const LatticeSectionLabel('Terrain / Obstacles'),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _terrainController,
                style: TextStyle(color: context.lattice.colors.textPrimary, fontSize: 13),
                maxLines: 2,
                minLines: 1,
                decoration:
                    latticeInputDecoration(context.lattice.colors, hint: 'Describe terrain, obstacles, hazards...'),
              ),
            ),
            const SizedBox(width: 8),
            LatticeMicButton(
              listening: _micListening,
              onTap: () => _dictateToField(_terrainController),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── FOOTER ──
        Row(
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
                  onPressed: _onSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
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
        ),

        if (_statusMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _statusMessage!,
            style: TextStyle(color: colors.success, fontSize: 11),
          ),
        ],

        // Report history (saved/sent/received)
        if (_savedReports.isNotEmpty) ...[
          const SizedBox(height: 20),
          const LatticeSectionHeader(title:'REPORT HISTORY'),
          const SizedBox(height: 8),
          for (int i = 0; i < _savedReports.length; i++) _buildSavedReportCard(_savedReports[i], i),
        ],

      ],
    );
  }

  Widget _buildToggleRow(
      String label, bool value, ValueChanged<bool> onChanged) {
    final colors = context.lattice.colors;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: value
                  ? colors.accent
                  : colors.borderActive,
              width: 1,
            ),
            color: colors.surface,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style:
                      TextStyle(color: colors.textLabel, fontSize: 12),
                ),
              ),
              Container(
                width: 40,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: value
                      ? colors.accent
                      : colors.borderActive,
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment:
                      value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller,
      {ValueChanged<String>? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LatticeSectionLabel(label),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(color: context.lattice.colors.textPrimary, fontSize: 13),
          decoration: latticeInputDecoration(context.lattice.colors, hint: '0'),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSavedReportCard(_SavedReport rpt, int index) {
    final callsign =
        (rpt.data['callsign'] as String?)?.isNotEmpty == true
            ? rpt.data['callsign'] as String
            : 'Unknown';
    final urgSurg = (rpt.data['urgentSurgical'] as int?) ?? 0;
    final urg = (rpt.data['urgent'] as int?) ?? 0;
    final pri = (rpt.data['priority'] as int?) ?? 0;
    final rtn = (rpt.data['routine'] as int?) ?? 0;
    final totalPatients = urgSurg + urg + pri + rtn;
    final timeStr =
        '${rpt.timestamp.hour.toString().padLeft(2, '0')}:'
        '${rpt.timestamp.minute.toString().padLeft(2, '0')}';
    final isExpanded = _expandedReports.contains(index);

    final colors = context.lattice.colors;
    final (Color badgeBg, Color badgeFg, String badgeText) =
        switch (rpt.status) {
      _ReportStatus.saved => (
          colors.borderActive,
          colors.textLabel,
          'SAVED',
        ),
      _ReportStatus.sent => (
          const Color(0xFF1A3A1A),
          const Color(0xFF66BB6A),
          'SENT',
        ),
      _ReportStatus.received => (
          const Color(0xFF1A1A3A),
          colors.accent,
          'RECEIVED',
        ),
    };

    return GestureDetector(
      onTap: () => setState(() {
        if (isExpanded) {
          _expandedReports.remove(index);
        } else {
          _expandedReports.add(index);
        }
      }),
      child: Container(
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
                Icon(Icons.emergency,
                    size: 14, color: colors.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    callsign,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeFg,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: colors.inactive,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'PAX: $totalPatients',
                  style: TextStyle(
                      color: colors.inactive, fontSize: 10),
                ),
                const SizedBox(width: 8),
                Icon(Icons.access_time,
                    size: 10, color: colors.inactive),
                const SizedBox(width: 2),
                Text(
                  timeStr,
                  style: TextStyle(
                      color: colors.inactive, fontSize: 10),
                ),
                if (rpt.status == _ReportStatus.received &&
                    rpt.fromCallsign != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'From: ${rpt.fromCallsign}',
                    style: TextStyle(
                        color: colors.accent, fontSize: 10),
                  ),
                ],
                if (rpt.status == _ReportStatus.sent &&
                    rpt.deliveryReport != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${rpt.deliveryReport!.successCount}/${rpt.deliveryReport!.results.length} delivered',
                    style: TextStyle(
                        color: colors.success, fontSize: 10),
                  ),
                ],
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 8),
              Divider(color: colors.borderActive, height: 1),
              const SizedBox(height: 8),
              _buildField('Callsign', callsign),
              _buildField('DTG', (rpt.data['dtg'] as String?) ?? 'N/A'),
              _buildField('Incident', (rpt.data['incidentType'] as String?)?.toUpperCase() ?? 'N/A'),
              if ((rpt.data['pickupLat'] as num?) != null)
                _buildField('Pickup', '${(rpt.data['pickupLat'] as num).toStringAsFixed(6)}, ${(rpt.data['pickupLng'] as num).toStringAsFixed(6)}'),
              if ((rpt.data['gridRef'] as String?)?.isNotEmpty == true)
                _buildField('Grid Ref', rpt.data['gridRef'] as String),
              _buildField('Frequency', (rpt.data['frequency'] as String?)?.isNotEmpty == true ? rpt.data['frequency'] as String : 'N/A'),
              _buildField('Contact', (rpt.data['contactCallsign'] as String?)?.isNotEmpty == true ? rpt.data['contactCallsign'] as String : 'N/A'),
              const SizedBox(height: 4),
              Text('PATIENTS', style: TextStyle(color: colors.textSecondary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              if (urgSurg > 0) _buildField('Urgent Surg', '$urgSurg'),
              if (urg > 0) _buildField('Urgent', '$urg'),
              if (pri > 0) _buildField('Priority', '$pri'),
              if (rtn > 0) _buildField('Routine', '$rtn'),
              _buildField('Litter', '${(rpt.data['litter'] as int?) ?? 0}'),
              _buildField('Ambulatory', '${(rpt.data['ambulatory'] as int?) ?? 0}'),
              const SizedBox(height: 4),
              _buildField('Security', (rpt.data['securityLevel'] as String?)?.toUpperCase() ?? 'N/A'),
              _buildField('Marking', (rpt.data['markingMethod'] as String?)?.toUpperCase() ?? 'N/A'),
              _buildField('Nationality', (rpt.data['nationality'] as String?)?.toUpperCase() ?? 'N/A'),
              _buildField('Triage', (rpt.data['triageStatus'] as String?)?.toUpperCase() ?? 'N/A'),
              _buildField('NBC', (rpt.data['nbcContamination'] as bool? ?? false) ? 'YES' : 'NO'),
              if ((rpt.data['terrain'] as String?)?.isNotEmpty == true)
                _buildField('Terrain', rpt.data['terrain'] as String),
            ],
            if (rpt.status == _ReportStatus.saved) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: () => _sendSavedReport(rpt),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    'Send',
                    style: TextStyle(
                      color: colors.onAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, String value) {
    final colors = context.lattice.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: colors.textPrimary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  String _incidentLabel(_IncidentType t) {
    return switch (t) {
      _IncidentType.tic => 'TIC',
      _IncidentType.ied => 'IED',
      _IncidentType.accident => 'ACC',
      _IncidentType.training => 'TNG',
      _IncidentType.other => 'OTH',
    };
  }

  String _equipmentLabel(_SpecialEquipment e) {
    return switch (e) {
      _SpecialEquipment.none => 'NONE',
      _SpecialEquipment.hoist => 'HOIST',
      _SpecialEquipment.extraction => 'EXTR',
      _SpecialEquipment.ventilator => 'VENT',
    };
  }

  String _markingLabel(_MarkingMethod m) {
    return switch (m) {
      _MarkingMethod.panels => 'PNL',
      _MarkingMethod.pyrotechnic => 'PYRO',
      _MarkingMethod.smoke => 'SMK',
      _MarkingMethod.none => 'NONE',
      _MarkingMethod.irStrobe => 'IR',
    };
  }

  String _nationalityLabel(_Nationality n) {
    return switch (n) {
      _Nationality.usMilitary => 'US MIL',
      _Nationality.usCivilian => 'US CIV',
      _Nationality.coalition => 'COAL',
      _Nationality.epw => 'EPW',
      _Nationality.civilian => 'CIV',
    };
  }

}


class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accent.withValues(alpha: 0.1)
              : colors.surface,
          border: Border.all(
            color: isSelected
                ? colors.accent
                : colors.borderActive,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? colors.accent
                  : colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecurityButton extends StatelessWidget {
  final _SecurityLevel level;
  final bool isSelected;
  final VoidCallback onTap;

  const _SecurityButton({
    required this.level,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeColors = context.lattice.colors;
    final domainColors = _securityColors(level);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? domainColors.$1 : themeColors.surface,
          border: Border.all(
            color: isSelected ? domainColors.$2 : themeColors.borderActive,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            _securityLabel(level),
            style: TextStyle(
              color: isSelected ? domainColors.$3 : themeColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  static String _securityLabel(_SecurityLevel s) {
    return switch (s) {
      _SecurityLevel.noEnemy => 'NO ENEMY (GREEN)',
      _SecurityLevel.possibleEnemy => 'POSSIBLE ENEMY (AMBER)',
      _SecurityLevel.enemyInArea => 'ENEMY IN AREA (RED)',
      _SecurityLevel.armedEscort => 'ARMED ESCORT REQ\'D (RED)',
    };
  }

  static (Color, Color, Color) _securityColors(_SecurityLevel s) {
    return switch (s) {
      _SecurityLevel.noEnemy => (
          const Color(0xFF1A3A1A),
          const Color(0xFF4CAF50),
          const Color(0xFF66BB6A),
        ),
      _SecurityLevel.possibleEnemy => (
          const Color(0xFF4A3000),
          const Color(0xFFFF9800),
          const Color(0xFFFFB74D),
        ),
      _SecurityLevel.enemyInArea => (
          const Color(0xFF5C1A1A),
          const Color(0xFFF44336),
          const Color(0xFFEF5350),
        ),
      _SecurityLevel.armedEscort => (
          const Color(0xFF3A0A0A),
          const Color(0xFFB71C1C),
          const Color(0xFFE53935),
        ),
    };
  }
}

class _TriageButton extends StatelessWidget {
  final _TriageStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  const _TriageButton({
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeColors = context.lattice.colors;
    final domainColors = _triageColors(status);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? domainColors.$1 : themeColors.surface,
          border: Border.all(
            color: isSelected ? domainColors.$2 : themeColors.borderActive,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            _triageLabel(status),
            style: TextStyle(
              color: isSelected ? domainColors.$3 : themeColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  static String _triageLabel(_TriageStatus t) {
    return switch (t) {
      _TriageStatus.immediate => 'IMMEDIATE',
      _TriageStatus.delayed => 'DELAYED',
      _TriageStatus.minimal => 'MINIMAL',
      _TriageStatus.expectant => 'EXPECTANT',
    };
  }

  static (Color, Color, Color) _triageColors(_TriageStatus t) {
    return switch (t) {
      _TriageStatus.immediate => (
          const Color(0xFF5C1A1A),
          const Color(0xFFF44336),
          const Color(0xFFEF5350),
        ),
      _TriageStatus.delayed => (
          const Color(0xFF4A3000),
          const Color(0xFFFF9800),
          const Color(0xFFFFB74D),
        ),
      _TriageStatus.minimal => (
          const Color(0xFF1A3A1A),
          const Color(0xFF4CAF50),
          const Color(0xFF66BB6A),
        ),
      _TriageStatus.expectant => (
          LatticeColorScheme.dark.surfaceElevated,
          LatticeColorScheme.dark.inactive,
          LatticeColorScheme.dark.textPrimary,
        ),
    };
  }
}


