import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/vehicle_type.dart';
import 'package:circle_x/presentation/inspection/vehicle_manual_picker.dart';

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
      builder: (_) =>
          VehicleManualPicker(vehicles: vehicles, selected: selected),
    );
    if (context.mounted && choice != null) onSelected?.call(choice);
  }

  @override
  Widget build(BuildContext context) => OutlinedButton(
        key: const ValueKey('vehicle-manual-selector'),
        onPressed: onSelected == null ? null : () => choose(context),
        style: OutlinedButton.styleFrom(
          backgroundColor: surface,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.all(14),
        ),
        child: Row(children: [
          const Icon(Icons.menu_book_outlined,
              color: serviceableGreen, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(selected.displayName,
                  style: const TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(selected.variant,
                  style: const TextStyle(color: textSecondary, fontSize: 12)),
              const SizedBox(height: 2),
              Text(selected.technicalManual,
                  style: const TextStyle(color: textSecondary, fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.unfold_more, color: textSecondary),
        ]),
      );
}
