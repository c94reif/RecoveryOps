import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';

/// Upload new objects to the Lattice CDN with an optional TTL.
class UploadTab extends StatefulWidget {
  const UploadTab({super.key, required this.context});
  final ExtensionContext context;

  @override
  State<UploadTab> createState() => _UploadTabState();
}

class _UploadTabState extends State<UploadTab> {
  final _pathController = TextEditingController();
  final _bodyController = TextEditingController();
  final _ttlController = TextEditingController();
  bool _uploading = false;
  String? _error;
  String? _pathError;
  ObjectUploadResult? _lastResult;

  @override
  void dispose() {
    _pathController.dispose();
    _bodyController.dispose();
    _ttlController.dispose();
    super.dispose();
  }

  static final _validPathPattern = RegExp(r'^[A-Za-z0-9._-]+$');

  Future<void> _upload() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      setState(() => _error = 'Object path is required');
      return;
    }
    if (!_validPathPattern.hasMatch(path)) {
      setState(
        () =>
            _error =
                'Invalid path. Only A-Z, a-z, 0-9, ".", "_", "-" are allowed.',
      );
      return;
    }
    final body = _bodyController.text;
    if (body.isEmpty) {
      setState(() => _error = 'Body content is required');
      return;
    }

    final ttlSec = int.tryParse(_ttlController.text.trim());
    final ttl = ttlSec != null && ttlSec > 0 ? Duration(seconds: ttlSec) : null;

    setState(() {
      _uploading = true;
      _error = null;
      _lastResult = null;
    });

    try {
      final bytes = Uint8List.fromList(utf8.encode(body));
      final result = await widget.context.objects.upload(path, bytes, ttl: ttl);
      setState(() {
        _uploading = false;
        _lastResult = result;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Uploaded to ${result.path}')));
      }
    } catch (e) {
      setState(() {
        _uploading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section label
          Text(
            'UPLOAD OBJECT',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),

          // Object path
          TextField(
            controller: _pathController,
            style: TextStyle(color: colors.textPrimary, fontSize: 13),
            onChanged: (value) {
              final trimmed = value.trim();
              if (trimmed.isNotEmpty && !_validPathPattern.hasMatch(trimmed)) {
                setState(
                  () =>
                      _pathError = 'Only A-Z, a-z, 0-9, ".", "_", "-" allowed',
                );
              } else {
                setState(() => _pathError = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'Object Path',
              labelStyle: TextStyle(color: colors.textMuted, fontSize: 12),
              hintText: 'e.g. myapp-report.json',
              hintStyle: TextStyle(color: colors.textMuted, fontSize: 12),
              errorText: _pathError,
              errorStyle: TextStyle(color: colors.error, fontSize: 11),
              filled: true,
              fillColor: colors.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: colors.borderActive),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Body content
          TextField(
            controller: _bodyController,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
            maxLines: 8,
            decoration: InputDecoration(
              labelText: 'Content (text/JSON)',
              labelStyle: TextStyle(color: colors.textMuted, fontSize: 12),
              hintText: '{"key": "value"}',
              hintStyle: TextStyle(color: colors.textMuted, fontSize: 12),
              filled: true,
              fillColor: colors.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: colors.borderActive),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // TTL
          TextField(
            controller: _ttlController,
            style: TextStyle(color: colors.textPrimary, fontSize: 13),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'TTL (seconds, optional)',
              labelStyle: TextStyle(color: colors.textMuted, fontSize: 12),
              hintText: 'Leave empty for default (90 days)',
              hintStyle: TextStyle(color: colors.textMuted, fontSize: 12),
              filled: true,
              fillColor: colors.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: colors.borderActive),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Upload button
          ElevatedButton.icon(
            onPressed: _uploading ? null : _upload,
            icon:
                _uploading
                    ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.textPrimary,
                      ),
                    )
                    : const Icon(Icons.cloud_upload, size: 18),
            label: Text(_uploading ? 'Uploading...' : 'Upload'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              minimumSize: const Size.fromHeight(48),
            ),
          ),

          // Error
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.error.withValues(alpha: 0.3)),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: colors.error, fontSize: 11),
              ),
            ),
          ],

          // Success result
          if (_lastResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: colors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload successful',
                    style: TextStyle(
                      color: colors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Path: ${_lastResult!.path}',
                    style: TextStyle(color: colors.textSecondary, fontSize: 11),
                  ),
                  if (_lastResult!.checksum != null)
                    Text(
                      'Checksum: ${_lastResult!.checksum}',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
