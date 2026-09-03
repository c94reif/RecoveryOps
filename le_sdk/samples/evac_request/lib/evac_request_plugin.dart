import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';

/// "Call for Evac" plugin — Dart implementation.
///
/// Provides a form for submitting MEDEVAC / evacuation requests with
/// priority classification, patient count, location picker (drops a
/// medical cross marker on the map), and situation notes.
class EvacRequestPlugin extends LatticeEdgeExtension {
  @override
  String get id => 'evac_request';

  @override
  String get name => 'Call for Evac';

  @override
  String get description =>
      'Submit MEDEVAC / evacuation requests with location and priority';

  @override
  IconData get icon => Icons.local_hospital;

  @override
  String? get iconAsset => 'assets/logo.png';

  @override
  ExtensionDisplayMode get defaultDisplayMode => ExtensionDisplayMode.panel;

  @override
  Widget build(ExtensionContext context) => _EvacRequestForm(context: context);
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

enum _Priority { urgent, priority, routine }

class _EvacRequestForm extends StatefulWidget {
  final ExtensionContext context;

  const _EvacRequestForm({required this.context});

  @override
  State<_EvacRequestForm> createState() => _EvacRequestFormState();
}

class _EvacRequestFormState extends State<_EvacRequestForm> {
  final _callsignController = TextEditingController();
  final _situationController = TextEditingController();
  final _callsignFocusNode = FocusNode();
  final _scrollController = ScrollController();
  _Priority _priority = _Priority.urgent;
  int _patients = 1;
  LatLng? _selectedLocation;
  String? _statusMessage;
  String? _callsignError;
  String? _locationError;
  bool _micListening = false;
  final _savedReports = <_SavedReport>[];
  final _expandedReports = <int>{};

  @override
  void initState() {
    super.initState();
    _loadReports();

    widget.context.messaging.markAllAsRead();

    widget.context.messaging.onMessageReceived.listen((msg) {
      final data = jsonDecode(msg.payload);
      if (data['type'] == 'evac_request') {
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

  @override
  void dispose() {
    _callsignController.dispose();
    _situationController.dispose();
    _callsignFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final location = await widget.context.map.pickLocation();
    if (location != null) {
      setState(() {
        _selectedLocation = location;
        _locationError = null;
      });
      // Drop a medical cross marker at the pickup location
      final callsign = _callsignController.text.trim().isNotEmpty
          ? _callsignController.text.trim()
          : 'MEDEVAC';
      await widget.context.map.addMarker(
        location,
        label: '\u2720 $callsign',
      );
    }
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

  Map<String, dynamic> _collectFormData() {
    return {
      'callsign': _callsignController.text.trim(),
      'priority': _priority.name,
      'patients': _patients,
      'situation': _situationController.text.trim(),
      'latitude': _selectedLocation?.latitude,
      'longitude': _selectedLocation?.longitude,
    };
  }

  bool _validateRequired() {
    bool valid = true;
    setState(() {
      _callsignError = null;
      _locationError = null;

      if (_callsignController.text.trim().isEmpty) {
        _callsignError = 'Callsign is required';
        valid = false;
      }
      if (_selectedLocation == null) {
        _locationError = 'Pickup location is required';
        valid = false;
      }
    });

    if (!valid) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      if (_callsignError != null) {
        _callsignFocusNode.requestFocus();
      }
    }
    return valid;
  }

  void _resetForm() {
    _callsignController.clear();
    _situationController.clear();
    _selectedLocation = null;
    _patients = 1;
    _priority = _Priority.urgent;
    _statusMessage = null;
    _callsignError = null;
    _locationError = null;
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
      _statusMessage = 'Request saved';
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
      'type': 'evac_request',
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
      'type': 'evac_request',
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
        // Priority selector
        const LatticeSectionLabel('Priority'),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final p in _Priority.values) ...[
              if (p != _Priority.urgent) const SizedBox(width: 6),
              Expanded(
                child: _PriorityButton(
                  priority: p,
                  isSelected: _priority == p,
                  onTap: () => setState(() => _priority = p),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        // Callsign
        const LatticeSectionLabel('CALLSIGN / REFERENCE', isRequired: true),
        const SizedBox(height: 4),
        TextField(
          controller: _callsignController,
          focusNode: _callsignFocusNode,
          style: TextStyle(color: context.lattice.colors.textPrimary, fontSize: 13),
          decoration: latticeInputDecoration(context.lattice.colors, hint: 'e.g. DUSTOFF 7-2', hasError: _callsignError != null),
          onChanged: (_) {
            if (_callsignError != null) setState(() => _callsignError = null);
          },
        ),
        if (_callsignError != null) ...[
          const SizedBox(height: 4),
          Text(
            _callsignError!,
            style: TextStyle(color: colors.error, fontSize: 11),
          ),
        ],
        const SizedBox(height: 10),

        // Patients
        const LatticeSectionLabel('Patients'),
        const SizedBox(height: 4),
        Row(
          children: [
            _StepperButton(
              label: '\u2212',
              onTap: _patients > 1
                  ? () => setState(() => _patients--)
                  : null,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              child: Text(
                '$_patients',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _StepperButton(
              label: '+',
              onTap: _patients < 99
                  ? () => setState(() => _patients++)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Situation with mic button
        const LatticeSectionLabel('Situation / Notes'),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _situationController,
                style: TextStyle(color: context.lattice.colors.textPrimary, fontSize: 13),
                maxLines: 3,
                minLines: 2,
                decoration:
                    latticeInputDecoration(context.lattice.colors, hint: 'Describe injuries, hazards, LZ conditions...'),
              ),
            ),
            const SizedBox(width: 8),
            LatticeMicButton(
              listening: _micListening,
              onTap: () => _dictateToField(_situationController),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Location picker
        const LatticeSectionLabel('PICKUP LOCATION', isRequired: true),
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
        if (_locationError != null) ...[
          const SizedBox(height: 4),
          Text(
            _locationError!,
            style: TextStyle(color: colors.error, fontSize: 11),
          ),
        ],
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
          const LatticeSectionLabel('REQUEST HISTORY'),
          const SizedBox(height: 8),
          for (int i = 0; i < _savedReports.length; i++) _buildSavedReportCard(_savedReports[i], i),
        ],
      ],
    );
  }

  Widget _buildSavedReportCard(_SavedReport rpt, int index) {
    final callsign =
        (rpt.data['callsign'] as String?)?.isNotEmpty == true
            ? rpt.data['callsign'] as String
            : 'Unknown';
    final patients = (rpt.data['patients'] as int?) ?? 0;
    final situation = (rpt.data['situation'] as String?) ?? '';
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
                Icon(Icons.local_hospital,
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
            if (!isExpanded && situation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                situation,
                style: TextStyle(color: colors.textSecondary, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '$patients patient${patients == 1 ? '' : 's'}',
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
              _buildField('Priority', (rpt.data['priority'] as String?)?.toUpperCase() ?? 'N/A'),
              _buildField('Callsign', callsign),
              _buildField('Patients', '$patients'),
              if ((rpt.data['latitude'] as num?) != null)
                _buildField('Location', '${(rpt.data['latitude'] as num).toStringAsFixed(6)}, ${(rpt.data['longitude'] as num).toStringAsFixed(6)}'),
              if (situation.isNotEmpty) _buildField('Situation', situation),
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
            width: 80,
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

}

class _PriorityButton extends StatelessWidget {
  final _Priority priority;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityButton({
    required this.priority,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeColors = context.lattice.colors;
    final domainColors = _priorityColors(priority);
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
            priority.name.toUpperCase(),
            style: TextStyle(
              color: isSelected ? domainColors.$3 : themeColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  static (Color, Color, Color) _priorityColors(_Priority p) {
    return switch (p) {
      _Priority.urgent => (
          const Color(0xFF5C1A1A),
          const Color(0xFFFF4444),
          const Color(0xFFEF5350)
        ),
      _Priority.priority => (
          const Color(0xFF4A3000),
          const Color(0xFFFF9800),
          const Color(0xFFFFB74D)
        ),
      _Priority.routine => (
          const Color(0xFF1A3A1A),
          const Color(0xFF4CAF50),
          const Color(0xFF66BB6A)
        ),
    };
  }
}

class _StepperButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _StepperButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.borderActive),
          color: colors.surface,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: onTap != null
                  ? colors.textSecondary
                  : colors.borderActive,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}
