import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';

class IconMarkersDemoPanel extends StatefulWidget {
  final ExtensionContext context;
  const IconMarkersDemoPanel({super.key, required this.context});

  @override
  State<IconMarkersDemoPanel> createState() => _IconMarkersDemoPanelState();
}

class _IconMarkersDemoPanelState extends State<IconMarkersDemoPanel> {
  @override
  void dispose() {
    widget.context.map.clearMarkers();
    super.dispose();
  }

  int _markerCount = 0;
  LatLng? _pickedLocation;
  MarkerDisposition _selectedDisposition = MarkerDisposition.hostile;

  static const _icons = MarkerIcon.values;
  static const _dispositions = MarkerDisposition.values;

  Future<void> _pickLocation() async {
    final loc = await widget.context.map.pickLocation();
    if (loc != null) {
      setState(() => _pickedLocation = loc);
    }
  }

  Future<void> _placeAllIcons() async {
    final base = _pickedLocation;
    if (base == null) return;
    final disp = _selectedDisposition;
    var count = 0;
    for (var i = 0; i < _icons.length; i++) {
      final icon = _icons[i];
      final row = i ~/ 6;
      final col = i % 6;
      final lat = base.latitude + row * 0.006;
      final lng = base.longitude + col * 0.008;
      await widget.context.map.addMarker(
        LatLng(lat, lng),
        label: icon.name,
        icon: icon,
        disposition: disp,
      );
      count++;
    }
    setState(() => _markerCount += count);
  }

  Future<void> _placeAllDispositions() async {
    final base = _pickedLocation;
    if (base == null) return;
    var count = 0;
    for (var d = 0; d < _dispositions.length; d++) {
      final disp = _dispositions[d];
      for (var i = 0; i < _icons.length; i++) {
        final icon = _icons[i];
        final row = d * 3 + i ~/ 6;
        final col = i % 6;
        final lat = base.latitude + row * 0.006;
        final lng = base.longitude + col * 0.008;
        await widget.context.map.addMarker(
          LatLng(lat, lng),
          label: '${icon.name}\n${disp.name}',
          icon: icon,
          disposition: disp,
        );
        count++;
      }
    }
    setState(() => _markerCount += count);
  }

  Future<void> _clearAll() async {
    await widget.context.map.clearMarkers();
    setState(() {
      _markerCount = 0;
      _pickedLocation = null;
    });
  }

  Color _dispositionColor(MarkerDisposition d) {
    const c = LatticeColorScheme.dark;
    switch (d) {
      case MarkerDisposition.hostile:
        return c.entityHostile;
      case MarkerDisposition.friendly:
        return c.entityFriendly;
      case MarkerDisposition.neutral:
        return c.success;
      case MarkerDisposition.unknown:
        return c.statusPending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    final hasLocation = _pickedLocation != null;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step 1: Pick location
          Text(
            hasLocation
                ? 'Location: ${_pickedLocation!.latitude.toStringAsFixed(4)}, ${_pickedLocation!.longitude.toStringAsFixed(4)}'
                : 'Step 1: Pick a location on the map',
            style: TextStyle(fontSize: 14, color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _pickLocation,
            icon: const Icon(Icons.my_location),
            label: Text(hasLocation ? 'Change Location' : 'Pick Location'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor:
                  hasLocation ? colors.borderActive : colors.accent,
            ),
          ),
          const SizedBox(height: 16),

          // Step 2: Disposition
          Text('Step 2: Choose disposition:',
              style: TextStyle(color: colors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _dispositions.map((d) {
              final selected = d == _selectedDisposition;
              return ChoiceChip(
                label: Text(d.name.toUpperCase()),
                selected: selected,
                selectedColor: _dispositionColor(d),
                onSelected: (_) =>
                    setState(() => _selectedDisposition = d),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Step 3: Place markers
          Text(
            hasLocation
                ? 'Step 3: Place markers ($_markerCount placed)'
                : 'Step 3: Pick a location first',
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: hasLocation ? _placeAllIcons : null,
            icon: const Icon(Icons.place),
            label: const Text('Place 18 Icons'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: colors.accent,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: hasLocation ? _placeAllDispositions : null,
            icon: const Icon(Icons.grid_view),
            label: const Text('Place All 72 (18 icons x 4 dispositions)'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: colors.borderActive,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _markerCount > 0 ? _clearAll : null,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear All Markers'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}
