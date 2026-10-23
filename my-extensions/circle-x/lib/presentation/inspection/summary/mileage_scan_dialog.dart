import 'dart:async';

import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/vehicle/entities/mileage_reading.dart';
import 'package:circle_x/domain/vehicle/services/bumper_scanner_strategy.dart';
import 'package:circle_x/domain/vehicle/usecases/find_mileage_readings.dart';
import 'package:circle_x/presentation/common/widgets/custom_button.dart';
import 'package:circle_x/presentation/common/widgets/custom_text_field.dart';
import 'package:circle_x/presentation/inspection/viewfinder/bumper_viewfinder.dart';

class MileageScanDialog extends StatefulWidget {
  final BumperScannerStrategy? scanner;
  final MileageReading? initial;
  final bool startWithCamera;

  const MileageScanDialog({
    super.key,
    this.scanner,
    this.initial,
    this.startWithCamera = true,
  });

  @override
  State<MileageScanDialog> createState() => _MileageScanDialogState();
}

class _MileageScanDialogState extends State<MileageScanDialog>
    with WidgetsBindingObserver {
  final _draft = TextEditingController();
  MileageUnit _unit = MileageUnit.miles;
  List<MileageReading> _candidates = [];
  bool _manual = false;
  bool _starting = false;
  bool _ready = false;
  bool _reading = false;
  String? _message;
  int _operation = 0;

  MileageReading? get _value => MileageReading.parse(_draft.text, _unit);
  bool get _reviewing => !_manual && _candidates.isNotEmpty;
  bool get _supported => widget.scanner?.isSupported == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draft.text = widget.initial?.number ?? '';
    _unit = widget.initial?.unit ?? MileageUnit.miles;
    _manual = !widget.startWithCamera || !_supported;
    if (!_manual) {
      _draft.clear();
      unawaited(_start());
    } else if (widget.startWithCamera) {
      _message = 'Camera scanning is unavailable on this device. '
          'Type the odometer reading below.';
    }
  }

  Future<void> _start() async {
    final operation = ++_operation;
    setState(() {
      _manual = false;
      _starting = true;
      _ready = false;
      _candidates = [];
      _draft.clear();
      _message = null;
    });
    try {
      await widget.scanner!.start().timeout(const Duration(seconds: 20));
      if (!mounted || operation != _operation) return;
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted || operation != _operation) return;
      unawaited(widget.scanner?.stop());
      setState(() {
        _message = 'Camera unavailable. Check camera permission and try '
            'again, or enter mileage manually.';
      });
    } finally {
      if (mounted && operation == _operation) {
        setState(() => _starting = false);
      }
    }
  }

  Future<void> _read() async {
    if (!_ready || _reading) return;
    final operation = ++_operation;
    setState(() {
      _reading = true;
      _message = null;
    });
    try {
      final lines =
          await widget.scanner!.read().timeout(const Duration(seconds: 15));
      if (!mounted || operation != _operation) return;
      final candidates = findMileageReadings(lines);
      if (candidates.isEmpty) {
        setState(() => _message = 'No odometer reading found. Move closer, '
            'reduce glare, and try again, or enter mileage manually.');
        return;
      }
      await widget.scanner!.stop();
      if (!mounted || operation != _operation) return;
      setState(() {
        _ready = false;
        _candidates = candidates;
        if (candidates.length == 1) _select(candidates.single);
      });
    } catch (_) {
      if (!mounted || operation != _operation) return;
      unawaited(widget.scanner?.stop());
      setState(() {
        _ready = false;
        _message = 'Could not read the dashboard. Open the camera to try '
            'again, or enter mileage manually.';
      });
    } finally {
      if (mounted && operation == _operation) {
        setState(() => _reading = false);
      }
    }
  }

  void _select(MileageReading reading) {
    _draft.text = reading.number;
    _unit = reading.unit;
  }

  void _enterManually() {
    _operation++;
    unawaited(widget.scanner?.stop());
    setState(() {
      _manual = true;
      _starting = false;
      _reading = false;
      _ready = false;
      _message = null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || (!_ready && !_starting)) return;
    _operation++;
    unawaited(widget.scanner?.stop());
    setState(() {
      _starting = false;
      _reading = false;
      _ready = false;
      _message = 'Camera paused. Open the camera to try again, '
          'or enter mileage manually.';
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _operation++;
    unawaited(widget.scanner?.stop());
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_manual ? 'Enter mileage' : 'Scan dashboard mileage',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _content(),
                const SizedBox(height: 8),
                if (_manual || _reviewing)
                  CustomButton(
                    text: _manual ? 'SAVE MILEAGE' : 'YES, USE MILEAGE',
                    onPressed: _value == null || _reading
                        ? null
                        : () => Navigator.of(context).pop(_value),
                  ),
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel')),
              ],
            )),
          ),
        ),
      );

  Widget _content() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_manual && !_reviewing) ...[
            const Text('Fill the camera view with the odometer digits, '
                'then tap Read mileage. Avoid the trip meter and hour meter.'),
            const SizedBox(height: 10),
            if (_starting) ...[
              const LinearProgressIndicator(),
              const Text('Opening camera…'),
            ] else if (_ready) ...[
              if (buildBumperViewfinder(widget.scanner!) case final preview?)
                preview,
              const SizedBox(height: 8),
              CustomButton(
                  text: _reading ? 'READING…' : 'READ MILEAGE',
                  icon: Icons.document_scanner_outlined,
                  onPressed: _reading ? null : _read),
            ] else
              CustomButton(text: 'OPEN CAMERA', onPressed: _start),
          ],
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(_message!, style: const TextStyle(color: circleXAmber)),
          ],
          if (_reviewing) ...[
            if (_candidates.length > 1) ...[
              const Text('Several readings found. Select the odometer value.'),
              Wrap(spacing: 8, children: [
                for (final reading in _candidates)
                  ChoiceChip(
                      label: Text(reading.display),
                      selected: _value?.display == reading.display,
                      onSelected: (_) => setState(() => _select(reading))),
              ]),
            ],
            if (_value != null) ...[
              const Text('Is this mileage correct?'),
              Text(_value!.display,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w700)),
            ],
          ],
          if (_manual) ...[
            CustomTextField(
                controller: _draft,
                label: 'Odometer reading',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autocorrect: false,
                errorText: _draft.text.isNotEmpty && _value == null
                    ? 'Enter 0–9,999,999.9 with at most one decimal place.'
                    : null,
                onChanged: (_) => setState(() {})),
          ],
          if (_manual || _reviewing) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<MileageUnit>(
              key: ValueKey(_unit),
              initialValue: _unit,
              decoration: const InputDecoration(labelText: 'Dashboard units'),
              items: [
                for (final unit in MileageUnit.values)
                  DropdownMenuItem(value: unit, child: Text(unit.label)),
              ],
              onChanged: (unit) => setState(() => _unit = unit!),
            ),
            const SizedBox(height: 8),
            const Text('Check the digits and units against the dashboard.'),
          ],
          if (!_manual)
            TextButton(
                onPressed: _enterManually,
                child: Text(_reviewing
                    ? 'No, enter manually'
                    : 'Enter mileage manually')),
          if (_supported && (_manual || _reviewing))
            TextButton(onPressed: _start, child: const Text('Scan again')),
        ],
      );
}
