import 'package:flutter/material.dart';
import 'package:circle_x/core/di/service_locator.dart';
import 'package:circle_x/domain/vehicle/entities/mileage_reading.dart';
import 'package:circle_x/domain/vehicle/services/bumper_scanner_strategy.dart';
import 'package:circle_x/presentation/common/widgets/custom_button.dart';
import 'package:circle_x/presentation/common/widgets/section_label.dart';
import 'package:circle_x/presentation/inspection/inspection_view_model.dart';
import 'package:circle_x/presentation/inspection/summary/mileage_scan_dialog.dart';

class MileageCard extends StatefulWidget {
  final InspectionViewModel viewModel;

  const MileageCard({super.key, required this.viewModel});

  @override
  State<MileageCard> createState() => _MileageCardState();
}

class _MileageCardState extends State<MileageCard> {
  bool _editing = false;
  String? _error;

  Future<void> _edit({required bool scan}) async {
    if (_editing || widget.viewModel.isBusy) return;
    setState(() {
      _editing = true;
      _error = null;
    });
    final scanner = scan && getIt.isRegistered<BumperScannerStrategy>()
        ? getIt<BumperScannerStrategy>()
        : null;
    try {
      final reading = await showDialog<MileageReading>(
        context: context,
        builder: (_) => MileageScanDialog(
          scanner: scanner,
          initial: widget.viewModel.session?.mileage,
          startWithCamera: scan,
        ),
      );
      await scanner?.dispose();
      if (!mounted || reading == null) return;
      final saved = await widget.viewModel.saveMileage(reading);
      if (mounted && !saved) {
        setState(() => _error = 'Mileage was not saved. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionLabel(text: 'DASHBOARD MILEAGE'),
              const SizedBox(height: 8),
              Text(widget.viewModel.session?.mileage == null
                  ? 'Record the odometer reading before signing your PMCS.'
                  : 'Confirmed mileage: ${widget.viewModel.session!.mileage!.display}'),
              const SizedBox(height: 12),
              CustomButton(
                text: 'SCAN MILEAGE',
                icon: Icons.document_scanner_outlined,
                onPressed: _editing ||
                        widget.viewModel.isBusy ||
                        widget.viewModel.isScanning
                    ? null
                    : () => _edit(scan: true),
              ),
              TextButton(
                onPressed: _editing ||
                        widget.viewModel.isBusy ||
                        widget.viewModel.isScanning
                    ? null
                    : () => _edit(scan: false),
                child: const Text('Enter mileage manually'),
              ),
              if (_error != null) Text(_error!),
            ],
          ),
        ),
      );
}
