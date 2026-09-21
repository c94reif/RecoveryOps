import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';

/// "LACE Report" plugin — Dart implementation.
///
/// Provides a form for submitting logistics status reports following the
/// US Army LACE format: Liquids, Ammunition, Casualties, Equipment.
class LaceReportPlugin extends LatticeEdgeExtension {
  @override
  String get id => 'lace_report';

  @override
  String get name => 'LACE Report';

  @override
  String get description =>
      'Submit logistics status reports (Liquids, Ammunition, Casualties, Equipment)';

  @override
  IconData get icon => Icons.assessment;

  @override
  String? get iconAsset => 'assets/logo.png';

  @override
  ExtensionDisplayMode get defaultDisplayMode => ExtensionDisplayMode.panel;

  @override
  Widget build(ExtensionContext context) => _LaceReportForm(context: context);
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

enum _AmmoStatus { green, amber, red, black }

enum _ReportingPeriod { hours6, hours12, hours24 }

class _LaceReportForm extends StatefulWidget {
  final ExtensionContext context;

  const _LaceReportForm({required this.context});

  @override
  State<_LaceReportForm> createState() => _LaceReportFormState();
}

class _LaceReportFormState extends State<_LaceReportForm> {
  // Header
  final _unitController = TextEditingController();
  final _dtgController = TextEditingController();
  _ReportingPeriod _reportingPeriod = _ReportingPeriod.hours24;

  // Validation
  final _unitFocusNode = FocusNode();
  final _strengthFocusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _unitError = false;
  bool _strengthError = false;

  // Liquids
  final _waterOnHandController = TextEditingController();
  bool _waterResupplyNeeded = false;
  final _waterNeededController = TextEditingController();
  final _fuelOnHandController = TextEditingController();
  bool _fuelResupplyNeeded = false;
  final _fuelNeededController = TextEditingController();

  // Ammunition
  _AmmoStatus _classIStatus = _AmmoStatus.green;
  _AmmoStatus _classIIIStatus = _AmmoStatus.green;
  _AmmoStatus _classVStatus = _AmmoStatus.green;
  _AmmoStatus _classVIIIStatus = _AmmoStatus.green;
  final _ammoRemarksController = TextEditingController();

  // Casualties
  final _totalStrengthController = TextEditingController();
  final _dutyCapableController = TextEditingController();
  final _wiaController = TextEditingController();
  final _kiaController = TextEditingController();
  final _miaController = TextEditingController();
  final _nbiController = TextEditingController();

  // Equipment
  final _fmcController = TextEditingController();
  final _pmcController = TextEditingController();
  final _nmcController = TextEditingController();
  final _equipShortagesController = TextEditingController();

  // Footer
  LatLng? _selectedLocation;
  String? _statusMessage;
  bool _micListening = false;
  final _savedReports = <_SavedReport>[];
  final _expandedReports = <int>{};

  @override
  void initState() {
    super.initState();
    _dtgController.text = _formatDtg(DateTime.now());
    _loadReports();

    widget.context.messaging.markAllAsRead();

    widget.context.messaging.onMessageReceived.listen((msg) {
      final data = jsonDecode(msg.payload);
      if (data['type'] == 'lace_report') {
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
  }

  @override
  void dispose() {
    _unitController.dispose();
    _dtgController.dispose();
    _waterOnHandController.dispose();
    _waterNeededController.dispose();
    _fuelOnHandController.dispose();
    _fuelNeededController.dispose();
    _ammoRemarksController.dispose();
    _totalStrengthController.dispose();
    _dutyCapableController.dispose();
    _wiaController.dispose();
    _kiaController.dispose();
    _miaController.dispose();
    _nbiController.dispose();
    _fmcController.dispose();
    _pmcController.dispose();
    _nmcController.dispose();
    _equipShortagesController.dispose();
    _unitFocusNode.dispose();
    _strengthFocusNode.dispose();
    _scrollController.dispose();
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
    // Month abbreviations
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    final month = months[dt.month - 1];
    final year = dt.year.toString().substring(2);
    return '$day$hour${min}Z $month $year';
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
      setState(() => _selectedLocation = location);
      final unit = _unitController.text.trim().isNotEmpty
          ? _unitController.text.trim()
          : 'LACE RPT';
      await widget.context.map.addMarker(
        location,
        label: '\u25A0 $unit',
      );
    }
  }

  Map<String, dynamic> _collectFormData() {
    return {
      'unit': _unitController.text.trim(),
      'dtg': _dtgController.text.trim(),
      'reportingPeriod': _reportingPeriod.name,
      'waterOnHand': int.tryParse(_waterOnHandController.text) ?? 0,
      'waterResupplyNeeded': _waterResupplyNeeded,
      'waterNeeded': int.tryParse(_waterNeededController.text) ?? 0,
      'fuelOnHand': int.tryParse(_fuelOnHandController.text) ?? 0,
      'fuelResupplyNeeded': _fuelResupplyNeeded,
      'fuelNeeded': int.tryParse(_fuelNeededController.text) ?? 0,
      'classI': _classIStatus.name,
      'classIII': _classIIIStatus.name,
      'classV': _classVStatus.name,
      'classVIII': _classVIIIStatus.name,
      'totalStrength': int.tryParse(_totalStrengthController.text) ?? 0,
      'dutyCapable': int.tryParse(_dutyCapableController.text) ?? 0,
      'wia': int.tryParse(_wiaController.text) ?? 0,
      'kia': int.tryParse(_kiaController.text) ?? 0,
      'mia': int.tryParse(_miaController.text) ?? 0,
      'nbi': int.tryParse(_nbiController.text) ?? 0,
      'fmc': int.tryParse(_fmcController.text) ?? 0,
      'pmc': int.tryParse(_pmcController.text) ?? 0,
      'nmc': int.tryParse(_nmcController.text) ?? 0,
      'latitude': _selectedLocation?.latitude,
      'longitude': _selectedLocation?.longitude,
    };
  }

  void _resetForm() {
    _unitController.clear();
    _dtgController.text = _formatDtg(DateTime.now());
    _reportingPeriod = _ReportingPeriod.hours24;
    _waterOnHandController.clear();
    _waterResupplyNeeded = false;
    _waterNeededController.clear();
    _fuelOnHandController.clear();
    _fuelResupplyNeeded = false;
    _fuelNeededController.clear();
    _classIStatus = _AmmoStatus.green;
    _classIIIStatus = _AmmoStatus.green;
    _classVStatus = _AmmoStatus.green;
    _classVIIIStatus = _AmmoStatus.green;
    _ammoRemarksController.clear();
    _totalStrengthController.clear();
    _dutyCapableController.clear();
    _wiaController.clear();
    _kiaController.clear();
    _miaController.clear();
    _nbiController.clear();
    _fmcController.clear();
    _pmcController.clear();
    _nmcController.clear();
    _equipShortagesController.clear();
    _selectedLocation = null;
    _statusMessage = null;
  }

  bool _validateRequired() {
    bool valid = true;
    setState(() {
      _unitError = false;
      _strengthError = false;
    });

    if (_unitController.text.trim().isEmpty) {
      setState(() => _unitError = true);
      valid = false;
    }
    if (_totalStrengthController.text.trim().isEmpty) {
      setState(() => _strengthError = true);
      valid = false;
    }

    if (!valid) {
      // Scroll to and focus the first error field
      if (_unitError) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
        _unitFocusNode.requestFocus();
      } else if (_strengthError) {
        _strengthFocusNode.requestFocus();
        // Scroll towards the Casualties section
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent * 0.5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    }

    return valid;
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
      'type': 'lace_report',
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
      'type': 'lace_report',
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

        Row(
          children: [
            Text(
              'UNIT DESIGNATION',
              style: TextStyle(
                color: colors.textLabel,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              ' *',
              style: TextStyle(
                color: colors.error,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _unitController,
          focusNode: _unitFocusNode,
          style: TextStyle(color: context.lattice.colors.textPrimary, fontSize: 13),
          decoration: latticeInputDecoration(context.lattice.colors, hint: 'e.g. 1PLT/A/2-501 INF', hasError: _unitError),
          onChanged: (_) {
            if (_unitError) setState(() => _unitError = false);
          },
        ),
        if (_unitError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              'Unit designation is required',
              style: TextStyle(color: colors.error, fontSize: 11),
            ),
          ),
        const SizedBox(height: 10),

        const LatticeSectionLabel('Date-Time Group (DTG)'),
        const SizedBox(height: 4),
        TextField(
          controller: _dtgController,
          style: TextStyle(color: context.lattice.colors.textPrimary, fontSize: 13),
          decoration: latticeInputDecoration(context.lattice.colors, hint: 'DDHHMMz MON YY'),
        ),
        const SizedBox(height: 10),

        const LatticeSectionLabel('Reporting Period'),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final p in _ReportingPeriod.values) ...[
              if (p != _ReportingPeriod.hours6) const SizedBox(width: 6),
              Expanded(
                child: _ToggleButton(
                  label: _periodLabel(p),
                  isSelected: _reportingPeriod == p,
                  onTap: () => setState(() => _reportingPeriod = p),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // ── L — LIQUIDS ──
        const LatticeSectionHeader(title:'L — LIQUIDS'),
        const SizedBox(height: 8),

        const LatticeSectionLabel('Water on Hand (gallons)'),
        const SizedBox(height: 4),
        TextField(
          controller: _waterOnHandController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: context.lattice.colors.textPrimary, fontSize: 13),
          decoration: latticeInputDecoration(context.lattice.colors, hint: '0'),
        ),
        const SizedBox(height: 8),

        _buildToggleRow(
          'Water Resupply Needed',
          _waterResupplyNeeded,
          (v) => setState(() => _waterResupplyNeeded = v),
        ),
        if (_waterResupplyNeeded) ...[
          const SizedBox(height: 8),
          const LatticeSectionLabel('Water Needed (gallons)'),
          const SizedBox(height: 4),
          TextField(
            controller: _waterNeededController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: context.lattice.colors.textPrimary, fontSize: 13),
            decoration: latticeInputDecoration(context.lattice.colors, hint: '0'),
          ),
        ],
        const SizedBox(height: 10),

        const LatticeSectionLabel('Fuel on Hand (gallons)'),
        const SizedBox(height: 4),
        TextField(
          controller: _fuelOnHandController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: context.lattice.colors.textPrimary, fontSize: 13),
          decoration: latticeInputDecoration(context.lattice.colors, hint: '0'),
        ),
        const SizedBox(height: 8),

        _buildToggleRow(
          'Fuel Resupply Needed',
          _fuelResupplyNeeded,
          (v) => setState(() => _fuelResupplyNeeded = v),
        ),
        if (_fuelResupplyNeeded) ...[
          const SizedBox(height: 8),
          const LatticeSectionLabel('Fuel Needed (gallons)'),
          const SizedBox(height: 4),
          TextField(
            controller: _fuelNeededController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: context.lattice.colors.textPrimary, fontSize: 13),
            decoration: latticeInputDecoration(context.lattice.colors, hint: '0'),
          ),
        ],
        const SizedBox(height: 16),

        // ── A — AMMUNITION ──
        const LatticeSectionHeader(title:'A — AMMUNITION'),
        const SizedBox(height: 8),

        _buildAmmoRow('Class I (Rations)', _classIStatus,
            (s) => setState(() => _classIStatus = s)),
        const SizedBox(height: 6),
        _buildAmmoRow('Class III (POL)', _classIIIStatus,
            (s) => setState(() => _classIIIStatus = s)),
        const SizedBox(height: 6),
        _buildAmmoRow('Class V (Ammunition)', _classVStatus,
            (s) => setState(() => _classVStatus = s)),
        const SizedBox(height: 6),
        _buildAmmoRow('Class VIII (Medical)', _classVIIIStatus,
            (s) => setState(() => _classVIIIStatus = s)),
        const SizedBox(height: 10),

        const LatticeSectionLabel('Critical Shortages / Remarks'),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _ammoRemarksController,
                style: TextStyle(color: context.lattice.colors.textPrimary, fontSize: 13),
                maxLines: 2,
                minLines: 1,
                decoration: latticeInputDecoration(context.lattice.colors, hint: 'Note critical shortages...'),
              ),
            ),
            const SizedBox(width: 8),
            LatticeMicButton(
              listening: _micListening,
              onTap: () => _dictateToField(_ammoRemarksController),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── C — CASUALTIES ──
        const LatticeSectionHeader(title:'C — CASUALTIES'),
        const SizedBox(height: 8),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'TOTAL STRENGTH',
                        style: TextStyle(
                          color: colors.textLabel,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        ' *',
                        style: TextStyle(
                          color: colors.error,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _totalStrengthController,
                    focusNode: _strengthFocusNode,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: context.lattice.colors.textPrimary, fontSize: 13),
                    decoration: latticeInputDecoration(context.lattice.colors, hint: '0', hasError: _strengthError),
                    onChanged: (_) {
                      if (_strengthError) setState(() => _strengthError = false);
                    },
                  ),
                  if (_strengthError)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        'Total strength is required',
                        style: TextStyle(color: colors.error, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child:
                  _buildNumberField('Duty Capable', _dutyCapableController),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildNumberField('WIA', _wiaController)),
            const SizedBox(width: 8),
            Expanded(child: _buildNumberField('KIA', _kiaController)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildNumberField('MIA', _miaController)),
            const SizedBox(width: 8),
            Expanded(
              child: _buildNumberField('Non-Battle Injuries', _nbiController),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── E — EQUIPMENT ──
        const LatticeSectionHeader(title:'E — EQUIPMENT'),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(child: _buildNumberField('FMC', _fmcController)),
            const SizedBox(width: 8),
            Expanded(child: _buildNumberField('PMC', _pmcController)),
            const SizedBox(width: 8),
            Expanded(child: _buildNumberField('NMC', _nmcController)),
          ],
        ),
        const SizedBox(height: 10),

        const LatticeSectionLabel('Key Equipment Shortages'),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _equipShortagesController,
                style: TextStyle(color: context.lattice.colors.textPrimary, fontSize: 13),
                maxLines: 2,
                minLines: 1,
                decoration: latticeInputDecoration(context.lattice.colors, hint: 'List critical equipment shortages...'),
              ),
            ),
            const SizedBox(width: 8),
            LatticeMicButton(
              listening: _micListening,
              onTap: () => _dictateToField(_equipShortagesController),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── FOOTER ──
        const LatticeSectionLabel('Unit Location'),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _pickLocation,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: colors.borderActive, width: 1),
                color: colors.surface,
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on,
                      size: 16, color: colors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedLocation != null
                          ? '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}'
                          : 'Pick location on map',
                      style: TextStyle(
                        color: _selectedLocation != null
                            ? colors.textPrimary
                            : colors.inactive,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (_selectedLocation != null)
                    IconButton(
                      icon: Icon(Icons.close,
                          size: 14, color: colors.inactive),
                      onPressed: () =>
                          setState(() => _selectedLocation = null),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Save / Send buttons
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
                  style: TextStyle(color: colors.textLabel, fontSize: 12),
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

  Widget _buildAmmoRow(
      String label, _AmmoStatus current, ValueChanged<_AmmoStatus> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LatticeSectionLabel(label),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final s in _AmmoStatus.values) ...[
              if (s != _AmmoStatus.green) const SizedBox(width: 6),
              Expanded(
                child: _AmmoStatusButton(
                  status: s,
                  isSelected: current == s,
                  onTap: () => onChanged(s),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller) {
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
        ),
      ],
    );
  }

  Widget _buildSavedReportCard(_SavedReport rpt, int index) {
    final unit =
        (rpt.data['unit'] as String?)?.isNotEmpty == true
            ? rpt.data['unit'] as String
            : 'Unknown';
    final totalStrength = (rpt.data['totalStrength'] as int?) ?? 0;
    final dutyCapable = (rpt.data['dutyCapable'] as int?) ?? 0;
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
                Icon(Icons.assessment,
                    size: 14, color: colors.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    unit,
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
                  'STR: $totalStrength  DC: $dutyCapable',
                  style:
                      TextStyle(color: colors.inactive, fontSize: 10),
                ),
                const SizedBox(width: 8),
                Icon(Icons.access_time,
                    size: 10, color: colors.inactive),
                const SizedBox(width: 2),
                Text(
                  timeStr,
                  style:
                      TextStyle(color: colors.inactive, fontSize: 10),
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
              _buildField('Unit', unit),
              _buildField('DTG', (rpt.data['dtg'] as String?) ?? 'N/A'),
              _buildField('Period', (rpt.data['reportingPeriod'] as String?)?.toUpperCase() ?? 'N/A'),
              const SizedBox(height: 4),
              Text('LIQUIDS', style: TextStyle(color: colors.textSecondary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              _buildField('Water On Hand', '${(rpt.data['waterOnHand'] as int?) ?? 0} gal'),
              if ((rpt.data['waterResupplyNeeded'] as bool?) == true)
                _buildField('Water Needed', '${(rpt.data['waterNeeded'] as int?) ?? 0} gal'),
              _buildField('Fuel On Hand', '${(rpt.data['fuelOnHand'] as int?) ?? 0} gal'),
              if ((rpt.data['fuelResupplyNeeded'] as bool?) == true)
                _buildField('Fuel Needed', '${(rpt.data['fuelNeeded'] as int?) ?? 0} gal'),
              const SizedBox(height: 4),
              Text('AMMUNITION', style: TextStyle(color: colors.textSecondary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              _buildField('Class I', (rpt.data['classI'] as String?)?.toUpperCase() ?? 'N/A'),
              _buildField('Class III', (rpt.data['classIII'] as String?)?.toUpperCase() ?? 'N/A'),
              _buildField('Class V', (rpt.data['classV'] as String?)?.toUpperCase() ?? 'N/A'),
              _buildField('Class VIII', (rpt.data['classVIII'] as String?)?.toUpperCase() ?? 'N/A'),
              const SizedBox(height: 4),
              Text('CASUALTIES', style: TextStyle(color: colors.textSecondary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              _buildField('Strength', '$totalStrength'),
              _buildField('Duty Capable', '$dutyCapable'),
              _buildField('WIA', '${(rpt.data['wia'] as int?) ?? 0}'),
              _buildField('KIA', '${(rpt.data['kia'] as int?) ?? 0}'),
              _buildField('MIA', '${(rpt.data['mia'] as int?) ?? 0}'),
              _buildField('NBI', '${(rpt.data['nbi'] as int?) ?? 0}'),
              const SizedBox(height: 4),
              Text('EQUIPMENT', style: TextStyle(color: colors.textSecondary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              _buildField('FMC', '${(rpt.data['fmc'] as int?) ?? 0}'),
              _buildField('PMC', '${(rpt.data['pmc'] as int?) ?? 0}'),
              _buildField('NMC', '${(rpt.data['nmc'] as int?) ?? 0}'),
              if ((rpt.data['latitude'] as num?) != null)
                _buildField('Location', '${(rpt.data['latitude'] as num).toStringAsFixed(6)}, ${(rpt.data['longitude'] as num).toStringAsFixed(6)}'),
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

  String _periodLabel(_ReportingPeriod p) {
    return switch (p) {
      _ReportingPeriod.hours6 => '6 HR',
      _ReportingPeriod.hours12 => '12 HR',
      _ReportingPeriod.hours24 => '24 HR',
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

class _AmmoStatusButton extends StatelessWidget {
  final _AmmoStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  const _AmmoStatusButton({
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeColors = context.lattice.colors;
    final domainColors = _ammoColors(status);
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
            status.name.toUpperCase(),
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

  static (Color, Color, Color) _ammoColors(_AmmoStatus s) {
    return switch (s) {
      _AmmoStatus.green => (
          const Color(0xFF1A3A1A),
          const Color(0xFF4CAF50),
          const Color(0xFF66BB6A),
        ),
      _AmmoStatus.amber => (
          const Color(0xFF4A3000),
          const Color(0xFFFF9800),
          const Color(0xFFFFB74D),
        ),
      _AmmoStatus.red => (
          const Color(0xFF5C1A1A),
          const Color(0xFFF44336),
          const Color(0xFFEF5350),
        ),
      _AmmoStatus.black => (
          LatticeColorScheme.dark.surfaceElevated,
          LatticeColorScheme.dark.inactive,
          LatticeColorScheme.dark.textPrimary,
        ),
    };
  }
}


