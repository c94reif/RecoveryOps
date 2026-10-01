import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/vehicle_type.dart';

class VehicleManualPicker extends StatefulWidget {
  final List<VehicleType> vehicles;
  final VehicleType selected;

  const VehicleManualPicker({
    super.key,
    required this.vehicles,
    required this.selected,
  });

  @override
  State<VehicleManualPicker> createState() => _VehicleManualPickerState();
}

class _VehicleManualPickerState extends State<VehicleManualPicker> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  String normalize(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  List<Object> filteredRows() {
    final terms = search.text
        .split(RegExp(r'\s+'))
        .map(normalize)
        .where((term) => term.isNotEmpty);
    final groups = <String, List<VehicleType>>{};
    for (final vehicle in widget.vehicles) {
      final searchable = normalize('${vehicle.family} ${vehicle.variant} '
          '${vehicle.displayName} ${vehicle.technicalManual}');
      if (terms.every(searchable.contains)) {
        groups.putIfAbsent(vehicle.family, () => []).add(vehicle);
      }
    }
    return [
      for (final entry in groups.entries) ...[entry.key, ...entry.value],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = filteredRows();
    return FractionallySizedBox(
      heightFactor: .85,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 12 + MediaQuery.viewInsetsOf(context).bottom),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(
                child: Text('Choose vehicle & TM',
                    style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700))),
            IconButton(
                tooltip: 'Close vehicle picker',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('vehicle-manual-search'),
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Search vehicle, variant, or TM',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear vehicle search',
                      onPressed: () => setState(search.clear),
                      icon: const Icon(Icons.clear)),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text('No matching vehicles or manuals.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textSecondary)))
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: rows.length,
                    itemBuilder: (context, index) => switch (rows[index]) {
                      final String family => Padding(
                          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                          child: Text(family.toUpperCase(),
                              style: const TextStyle(
                                  color: textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1))),
                      final VehicleType vehicle => buildOption(vehicle),
                      _ => const SizedBox.shrink(),
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  Widget buildOption(VehicleType vehicle) {
    final selected = vehicle == widget.selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: ValueKey(('vehicle-manual-option', vehicle.wireName)),
        selected: selected,
        selectedColor: textPrimary,
        textColor: textPrimary,
        tileColor: surfaceLight,
        selectedTileColor: greenGlow,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: selected ? serviceableGreen : border)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        title: Text(vehicle.variant,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(vehicle.technicalManual,
            style: const TextStyle(
                color: textSecondary, fontSize: 11, height: 1.5)),
        trailing: Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: selected ? serviceableGreen : textSecondary,
            size: 22),
        onTap: () => Navigator.of(context).pop(vehicle),
      ),
    );
  }
}
