import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';
import 'package:web/web.dart' as web;

import 'dart:js_interop';

class CorsTestPlugin {
  Widget build(ExtensionContext context) {
    return const _CorsTestBody();
  }
}

class _CorsTestBody extends StatefulWidget {
  const _CorsTestBody();

  @override
  State<_CorsTestBody> createState() => _CorsTestBodyState();
}

class _CorsTestBodyState extends State<_CorsTestBody> {
  static const _testUrl = 'https://github.com';

  String _status = 'Tap the button to test';
  Color _statusColor = LatticeColorScheme.dark.textSecondary;
  String _details = '';
  bool _loading = false;

  Future<void> _runTest() async {
    setState(() {
      _loading = true;
      _status = 'Fetching...';
      _statusColor = LatticeColorScheme.dark.textSecondary;
      _details = _testUrl;
    });

    try {
      final response = await web.window.fetch(_testUrl.toJS).toDart;
      final status = response.status;
      final body = (await response.text().toDart).toDart;
      setState(() {
        _loading = false;
        _status = 'OK — status $status';
        _statusColor = LatticeColorScheme.dark.success;
        _details = body.length > 500 ? '${body.substring(0, 500)}...' : body;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'FAILED';
        _statusColor = LatticeColorScheme.dark.error;
        _details = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CORS Proxy Test',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fetches an external URL via fetch(). Without a proxy, '
            'this fails with a CORS error. With the proxy configured, '
            'it succeeds.',
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _runTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.textPrimary,
                      ),
                    )
                  : const Text('Fetch External API'),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              _status,
              style: TextStyle(
                color: _statusColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_details.isNotEmpty)
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: SelectableText(
                    _details,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
