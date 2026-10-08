import 'dart:async';

import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/services/pmcs_notification_port.dart';

/// Phone preferences are saved independently of the profile's editable fields.
class PmcsNotificationSettingsCard extends StatefulWidget {
  final PmcsNotificationPort notifications;

  const PmcsNotificationSettingsCard({
    super.key,
    required this.notifications,
  });

  @override
  State<PmcsNotificationSettingsCard> createState() =>
      _PmcsNotificationSettingsCardState();
}

class _PmcsNotificationSettingsCardState
    extends State<PmcsNotificationSettingsCard> with WidgetsBindingObserver {
  PmcsNotificationStatus? _status;
  String? _error;
  String? _activity;
  bool _refreshPending = false;
  int _generation = 0;

  bool get _busy => _activity != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(PmcsNotificationSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(widget.notifications, oldWidget.notifications)) return;
    _generation++;
    _status = null;
    _activity = null;
    _refreshPending = false;
    unawaited(_refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() {
    if (_busy) {
      _refreshPending = true;
      return Future.value();
    }
    return _run(
      (notifications) => notifications.getStatus(),
      activity: 'Loading notification settings…',
      error: 'Could not load notification settings. Try again.',
    );
  }

  Future<void> _setEnabled(bool value) {
    if (_busy || _status?.supported != true) return Future.value();
    return _run(
      // Only this explicit switch action can request phone permission.
      (notifications) => notifications.setEnabled(value),
      activity: 'Saving notification preference…',
      error: 'Could not update notification settings. Try again.',
    );
  }

  Future<void> _openSettings() => _run(
        (notifications) async {
          await notifications.openSettings();
          return notifications.getStatus();
        },
        activity: 'Opening notification settings…',
        error: 'Could not open notification settings. Try again.',
      );

  Future<void> _run(
    Future<PmcsNotificationStatus> Function(PmcsNotificationPort) action, {
    required String activity,
    required String error,
  }) async {
    if (_busy) return;
    final generation = ++_generation;
    setState(() {
      _activity = activity;
      _error = null;
    });
    try {
      final status = await action(widget.notifications);
      if (!mounted || generation != _generation) return;
      setState(() => _status = status);
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = error);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _activity = null);
        if (_refreshPending) {
          _refreshPending = false;
          unawaited(_refresh());
        }
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final blocked = status != null &&
        status.supported &&
        status.enabled &&
        !status.permissionGranted;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgDark,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Silent PMCS notifications',
                    style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: 'Silent PMCS notifications',
                child: Switch(
                  value: status?.enabled ?? false,
                  onChanged:
                      status?.supported == true && !_busy ? _setEnabled : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Incoming PMCS reports from your default and followed units, '
            'without sound or vibration.',
            style: _bodyStyle,
          ),
          if (_activity != null) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(_activity!, style: _bodyStyle),
          ],
          if (status != null && !status.supported) ...[
            const SizedBox(height: 12),
            const Text('Phone notifications are unavailable in this version.',
                style: _bodyStyle),
          ],
          if (blocked) ...[
            const SizedBox(height: 12),
            const Text(
              'Allow notifications in your phone settings to receive them.',
              style: _bodyStyle,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : _openSettings,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(minTouchTarget),
                  padding: const EdgeInsets.all(12),
                ),
                child: const Text('Open notification settings',
                    textAlign: TextAlign.center),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(_error!, style: const TextStyle(color: redXRed)),
            ),
            TextButton(
              onPressed: _busy ? null : _refresh,
              style: TextButton.styleFrom(
                  minimumSize: const Size(minTouchTarget, minTouchTarget)),
              child: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

const _bodyStyle = TextStyle(
  color: textSecondary,
  fontSize: 13,
  height: 1.45,
);
