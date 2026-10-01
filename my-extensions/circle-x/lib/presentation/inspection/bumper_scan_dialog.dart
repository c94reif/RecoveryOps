import 'dart:async';

import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/services/bumper_scanner_strategy.dart';
import 'package:circle_x/domain/usecases/vehicle/find_bumper_markings.dart';
import 'package:circle_x/presentation/common/widgets/custom_button.dart';
import 'package:circle_x/presentation/common/widgets/custom_text_field.dart';
import 'package:circle_x/presentation/inspection/viewfinder/bumper_viewfinder.dart';

class BumperScanDialog extends StatefulWidget {
  final BumperScannerStrategy scanner;

  const BumperScanDialog({super.key, required this.scanner});

  @override
  State<BumperScanDialog> createState() => _BumperScanDialogState();
}

class _BumperScanDialogState extends State<BumperScanDialog>
    with WidgetsBindingObserver {
  final _draft = TextEditingController();
  final _selected = <String>[];
  List<String> _markings = [];
  bool _starting = true;
  bool _ready = false;
  bool _reading = false;
  String? _message;
  int _operation = 0;

  bool get _canUse =>
      !_reading &&
      !_starting &&
      _selected.isNotEmpty &&
      _draft.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  Future<void> _start() async {
    final operation = ++_operation;
    setState(() {
      _starting = true;
      _message = null;
    });
    try {
      await widget.scanner.start().timeout(const Duration(seconds: 20));
      if (!mounted || operation != _operation) return;
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted || operation != _operation) return;
      unawaited(widget.scanner.stop());
      setState(() => _message = BumperScanFailure.unavailable.message);
    } finally {
      if (mounted && operation == _operation) {
        setState(() => _starting = false);
      }
    }
  }

  Future<void> _read() async {
    if (!_ready || _reading) return;
    final operation = ++_operation;
    FocusScope.of(context).unfocus();
    setState(() {
      _reading = true;
      _markings = [];
      _selected.clear();
      _draft.clear();
      _message = null;
    });
    try {
      final lines = await widget.scanner.read();
      if (!mounted || operation != _operation) return;
      setState(() {
        _markings = findBumperMarkings(lines);
        if (_markings.isEmpty) {
          _message = 'No markings found. Move closer to the letters and '
              'numbers, then tap Read markings again.';
        }
      });
    } catch (error) {
      if (!mounted || operation != _operation) return;
      setState(() => _message =
          (error is BumperScanFailure ? error : BumperScanFailure.unreadable)
              .message);
    } finally {
      if (mounted && operation == _operation) {
        setState(() => _reading = false);
      }
    }
  }

  void _select(String marking, bool selected) {
    setState(() {
      selected ? _selected.add(marking) : _selected.remove(marking);
      final text = _selected.join(' ');
      _draft.value = TextEditingValue(
          text: text, selection: TextSelection.collapsed(offset: text.length));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || !_ready) return;
    _operation++;
    unawaited(widget.scanner.stop());
    setState(() {
      _ready = false;
      _reading = false;
      _message = 'Camera paused. Tap Open camera to read again.';
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _operation++;
    unawaited(widget.scanner.stop());
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Scan bumper number',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Flexible(child: SingleChildScrollView(child: _buildContent())),
              const SizedBox(height: 12),
              Row(children: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel')),
                const SizedBox(width: 8),
                Expanded(
                    child: CustomButton(
                  text: 'USE BUMPER NUMBER',
                  onPressed: _canUse
                      ? () => Navigator.of(context)
                          .pop(_draft.text.trim().toUpperCase())
                      : null,
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Aim at the vehicle’s bumper and tap Read markings.',
              style: TextStyle(color: textSecondary, height: 1.4)),
          const SizedBox(height: 10),
          if (_starting) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Opening camera…'),
          ] else if (_ready) ...[
            if (buildBumperViewfinder(widget.scanner) case final preview?)
              preview,
            const SizedBox(height: 8),
            CustomButton(
                text: _reading ? 'READING…' : 'READ MARKINGS',
                icon: Icons.document_scanner_outlined,
                onPressed: _reading ? null : _read),
          ] else
            CustomButton(
                text: 'OPEN CAMERA',
                icon: Icons.photo_camera_outlined,
                onPressed: _start),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!,
                style: const TextStyle(color: circleXAmber, height: 1.4)),
          ],
          if (_markings.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Select the marking(s) for the bumper number.',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
                'If it is split across lines, select the parts in order.',
                style: TextStyle(color: textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final marking in _markings)
                FilterChip(
                    label: Text(marking),
                    selected: _selected.contains(marking),
                    onSelected: (selected) => _select(marking, selected)),
            ]),
          ],
          if (_selected.isNotEmpty) ...[
            const SizedBox(height: 12),
            CustomTextField(
                controller: _draft,
                label: 'Selected bumper number',
                uppercase: true,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {})),
            const SizedBox(height: 8),
            const Text(
                'Review or correct the text, then tap Use bumper number.',
                style:
                    TextStyle(color: textSecondary, fontSize: 12, height: 1.4)),
          ],
        ],
      );
}
