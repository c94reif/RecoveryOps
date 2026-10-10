import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/followed_unit.dart';

class ReportUnitSelector extends StatelessWidget {
  static const all = '';
  static const other = '*';

  final List<FollowedUnit> units;
  final String selected;
  final ValueChanged<String> onChanged;

  const ReportUnitSelector({
    super.key,
    required this.units,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Unit',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const ValueKey('report-unit-selector'),
              value: selected,
              isExpanded: true,
              dropdownColor: surface,
              itemHeight: minTouchTarget,
              items: [
                const DropdownMenuItem(value: all, child: Text('All my units')),
                for (final unit in units)
                  DropdownMenuItem(
                    value: unit.normalizedUic,
                    child: Text(unit.label,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                const DropdownMenuItem(
                    value: other, child: Text('Other units')),
              ],
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ),
        ),
      );
}
