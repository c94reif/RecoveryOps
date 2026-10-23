import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/catalog/entities/vehicle_type.dart';
import 'package:circle_x/presentation/inspection/setup/vehicle_platform_card.dart';

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
      for (final entry in groups.entries) ...[
        if (entry.value.length > 1) entry.key,
        ...entry.value,
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = filteredRows();
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return FractionallySizedBox(
      heightFactor: keyboardInset > 0 ? 1 : .85,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + keyboardInset),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(
                child: Text('Choose platform',
                    style: TextStyle(
                        color: textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800))),
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
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              hintText: 'Search platform, variant or TM',
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
                          padding: const EdgeInsets.fromLTRB(2, 16, 2, 10),
                          child: Row(children: [
                            Text(family.toUpperCase(),
                                style: const TextStyle(
                                    color: textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4)),
                            const SizedBox(width: 12),
                            const Expanded(child: Divider()),
                          ])),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: VehiclePlatformCard(
        key: ValueKey(('vehicle-manual-option', vehicle.wireName)),
        vehicle: vehicle,
        selected: selected,
        onTap: () => Navigator.of(context).pop(vehicle),
      ),
    );
  }
}
