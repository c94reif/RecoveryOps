import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';

/// Sample "Field Report" plugin demonstrating the Lattice Plugin SDK.
///
/// Provides a form for submitting field reports with title, description,
/// optional location picked from the map, and photo attachments.
class FieldReportPlugin extends LatticeEdgeExtension {
  @override
  String get id => 'field_report';

  @override
  String get name => 'Field Report';

  @override
  String get description => 'Submit field observations and reports';

  @override
  IconData get icon => Icons.assignment;

  @override
  String? get iconAsset => 'assets/logo.png';

  @override
  ExtensionDisplayMode get defaultDisplayMode => ExtensionDisplayMode.panel;

  @override
  Widget build(ExtensionContext context) => _FieldReportForm(context: context);
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

class _FieldReportForm extends StatefulWidget {
  final ExtensionContext context;

  const _FieldReportForm({required this.context});

  @override
  State<_FieldReportForm> createState() => _FieldReportFormState();
}

class _FieldReportFormState extends State<_FieldReportForm> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  LatLng? _selectedLocation;
  String? _statusMessage;
  String? _titleError;
  final _attachedPhotos = <XFile>[];
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
      if (data['type'] == 'field_report') {
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
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final location = await widget.context.map.pickLocation();
    if (location != null) {
      setState(() => _selectedLocation = location);
    }
  }

  Future<void> _pickFromGallery() async {
    final images = await _imagePicker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (images.isNotEmpty) {
      setState(() => _attachedPhotos.addAll(images));
    }
  }

  Future<void> _takePhoto() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (photo != null) {
      setState(() => _attachedPhotos.add(photo));
    }
  }

  void _removePhoto(int index) {
    setState(() => _attachedPhotos.removeAt(index));
  }

  void _showPhotoOptions() {
    final colors = context.lattice.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera,
                  color: colors.accent, size: 22),
              title: Text('Take Photo',
                  style: TextStyle(color: colors.textPrimary, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                _takePhoto();
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library,
                  color: colors.accent, size: 22),
              title: Text('Choose from Gallery',
                  style: TextStyle(color: colors.textPrimary, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
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
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'submittedBy': widget.context.hostInfo.callsign,
      'latitude': _selectedLocation?.latitude,
      'longitude': _selectedLocation?.longitude,
      'photoPaths': _attachedPhotos.map((f) => f.path).toList(),
    };
  }

  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();
    _selectedLocation = null;
    _attachedPhotos.clear();
    _statusMessage = null;
    _titleError = null;
  }

  bool _validateRequired() {
    if (_titleController.text.trim().isEmpty) {
      setState(() {
        _titleError = 'Title is required';
        _statusMessage = null;
      });
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      _titleFocusNode.requestFocus();
      return false;
    }
    setState(() => _titleError = null);
    return true;
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
    final title = _titleController.text.trim();
    final reportData = _collectFormData();

    // Drop a marker if location was selected
    if (_selectedLocation != null) {
      await widget.context.map.addMarker(
        _selectedLocation!,
        label: 'Report: $title',
      );
    }

    final recipients = await widget.context.messaging.pickRecipients();
    if (recipients == null) return;

    final payload = jsonEncode({
      'type': 'field_report',
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
      'type': 'field_report',
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
        // Title field (required)
        Row(
          children: [
            Text(
              'REPORT TITLE',
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
        const SizedBox(height: 6),
        TextField(
          controller: _titleController,
          focusNode: _titleFocusNode,
          style: TextStyle(color: context.lattice.colors.textPrimary, fontSize: 13),
          decoration: latticeInputDecoration(context.lattice.colors,
              hint: 'Enter report title', hasError: _titleError != null),
          onChanged: (_) {
            if (_titleError != null) setState(() => _titleError = null);
          },
        ),
        if (_titleError != null) ...[
          const SizedBox(height: 4),
          Text(
            _titleError!,
            style: TextStyle(color: colors.error, fontSize: 11),
          ),
        ],
        const SizedBox(height: 10),

        // Description field with mic button
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _descriptionController,
                style: TextStyle(color: context.lattice.colors.textPrimary, fontSize: 13),
                maxLines: 4,
                minLines: 3,
                decoration: latticeInputDecoration(context.lattice.colors,
                    hint: 'Description (optional)'),
              ),
            ),
            const SizedBox(width: 8),
            LatticeMicButton(
              listening: _micListening,
              onTap: () => _dictateToField(_descriptionController),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Location picker
        GestureDetector(
          onTap: _pickLocation,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.borderActive, width: 1),
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
        const SizedBox(height: 10),

        // Photo attachments
        GestureDetector(
          onTap: _showPhotoOptions,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.borderActive, width: 1),
                color: colors.surface,
              ),
              child: Row(
                children: [
                  Icon(Icons.add_a_photo,
                      size: 16, color: colors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    _attachedPhotos.isEmpty
                        ? 'Add photos'
                        : '${_attachedPhotos.length} photo${_attachedPhotos.length == 1 ? '' : 's'} attached',
                    style: TextStyle(
                      color: _attachedPhotos.isNotEmpty
                          ? colors.textPrimary
                          : colors.inactive,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  if (_attachedPhotos.isNotEmpty)
                    Icon(Icons.add, size: 16, color: colors.textSecondary),
                ],
              ),
            ),
          ),
        ),

        // Photo thumbnails
        if (_attachedPhotos.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: _attachedPhotos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) => _buildPhotoThumbnail(i),
            ),
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
          Text(
            'REPORT HISTORY',
            style: TextStyle(
              color: colors.textLabel,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < _savedReports.length; i++) _buildSavedReportCard(_savedReports[i], i),
        ],
      ],
    );
  }

  Widget _buildPhotoThumbnail(int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(
            File(_attachedPhotos[index].path),
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () => _removePhoto(index),
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedReportCard(_SavedReport rpt, int index) {
    final title =
        (rpt.data['title'] as String?)?.isNotEmpty == true
            ? rpt.data['title'] as String
            : 'Untitled';
    final description = (rpt.data['description'] as String?) ?? '';
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
                Icon(Icons.assignment,
                    size: 14, color: colors.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
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
            if (!isExpanded && description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style:
                    TextStyle(color: colors.textSecondary, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
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
              _buildField('Title', title),
              if ((rpt.data['submittedBy'] as String?)?.isNotEmpty == true)
                _buildField('Submitted by', rpt.data['submittedBy'] as String),
              if (description.isNotEmpty) _buildField('Description', description),
              if ((rpt.data['latitude'] as num?) != null)
                _buildField('Location', '${(rpt.data['latitude'] as num).toStringAsFixed(6)}, ${(rpt.data['longitude'] as num).toStringAsFixed(6)}'),
              if ((rpt.data['photoPaths'] as List?)?.isNotEmpty == true)
                _buildField('Photos', '${(rpt.data['photoPaths'] as List).length} attached'),
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

