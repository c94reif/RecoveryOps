import 'package:flutter/material.dart';
import 'package:circle_x/domain/catalog/entities/vehicle_type.dart';
import 'package:circle_x/presentation/inspection/setup/vehicle_manual_picker.dart';
import 'package:circle_x/presentation/inspection/setup/vehicle_platform_card.dart';

class VehicleManualSelector extends StatelessWidget {
  final VehicleType selected;
  final List<VehicleType> vehicles;
  final ValueChanged<VehicleType>? onSelected;

  const VehicleManualSelector({
    super.key,
    required this.selected,
    required this.vehicles,
    required this.onSelected,
  });

  Future<void> choose(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final choice = await showModalBottomSheet<VehicleType>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          VehicleManualPicker(vehicles: vehicles, selected: selected),
    );
    if (context.mounted && choice != null) onSelected?.call(choice);
  }

  @override
  Widget build(BuildContext context) => VehiclePlatformCard(
        key: const ValueKey('vehicle-manual-selector'),
        vehicle: selected,
        selected: true,
        opensPicker: true,
        onTap: onSelected == null ? null : () => choose(context),
      );
}
