import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';

/// Sample extension that exercises the dynamic panel-resize API.
///
/// Demonstrates [UiService.setPanelSize] / [UiService.getPanelSize] and shows
/// how widgets reflow as the drawer width changes. Size is persisted via
/// [StorageService] — the host resets the shared drawer width on every plugin
/// transition, so plugins must remember their own size to keep it sticky.
class PanelResizeDemoPlugin extends LatticeEdgeExtension {
  @override
  String get id => 'panel_resize_demo';
  @override
  String get name => 'Panel Resize Demo';
  @override
  String get description =>
      'Grow / shrink / reset the plugin drawer and watch controls reflow';
  @override
  IconData get icon => Icons.aspect_ratio;
  @override
  String? get iconAsset => 'assets/logo.png';
  @override
  ExtensionDisplayMode get defaultDisplayMode => ExtensionDisplayMode.panel;

  @override
  Widget build(ExtensionContext context) =>
      _PanelResizeDemoView(context: context);
}

class _PanelResizeDemoView extends StatefulWidget {
  final ExtensionContext context;
  const _PanelResizeDemoView({required this.context});

  @override
  State<_PanelResizeDemoView> createState() => _PanelResizeDemoViewState();
}

class _PanelResizeDemoViewState extends State<_PanelResizeDemoView> {
  UiService get _ui => widget.context.ui;
  StorageService get _storage => widget.context.storage;

  /// Storage key for the persisted panel size — the host resets the shared
  /// drawer width on every plugin transition, so the plugin re-applies its own.
  static const _sizeStorageKey = 'panel_size';

  static const _initialSize = PanelSize.xsmall;

  /// Last known panel size, read back from the host after every change.
  PanelSize _size = _initialSize;

  /// True while a resize call is in flight; disables buttons to prevent overlapping requests.
  bool _busy = false;

  String? _hint;

  int _rebuilds = 0;

  // A controller is needed so text survives the rebuilds triggered by a resize.
  final TextEditingController _noteController = TextEditingController();

  static const _tags = [
    'recon', 'logistics', 'medical', 'fires', 'comms',
    'engineer', 'intel', 'aviation', 'armor', 'supply',
  ];
  final Set<String> _selectedTags = {'recon', 'fires'};

  double _readiness = 0.6;

  @override
  void initState() {
    super.initState();
    // Re-apply the saved size after first build: the host resets the shared
    // drawer width on every plugin transition, so we must push ours back.
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSavedSize());
  }

  Future<void> _restoreSavedSize() async {
    PanelSize target = _initialSize;
    final saved = await _storage.read(_sizeStorageKey);
    if (saved != null) {
      target = PanelSize.values.asNameMap()[saved] ?? _initialSize;
    }
    if (!mounted) return;
    // reset: true bypasses the "already at this size" guard — the host's width
    // was reset on entry, so we must push our remembered size through regardless.
    await _applySize(target, reset: true);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Resize actions
  // ---------------------------------------------------------------------------

  static const _order = [
    PanelSize.xsmall,
    PanelSize.small,
    PanelSize.medium,
    PanelSize.large,
  ];

  Future<void> _grow() => _applySize(_step(1));
  Future<void> _shrink() => _applySize(_step(-1));
  Future<void> _resetToSmallest() => _applySize(_order.first, reset: true);

  PanelSize _step(int delta) {
    final i = (_order.indexOf(_size) + delta).clamp(0, _order.length - 1);
    return _order[i];
  }

  Future<void> _applySize(PanelSize target, {bool reset = false}) async {
    if (_busy) return;
    if (target == _size && !reset) {
      setState(() => _hint =
          target == PanelSize.large ? 'Already at largest' : 'Already at smallest');
      return;
    }
    setState(() {
      _busy = true;
      _hint = null;
    });
    try {
      await _ui.setPanelSize(target);
      // Read back the actual size — the host may clamp or drop the request.
      final actual = await _ui.getPanelSize();
      await _storage.write(_sizeStorageKey, target.name);
      if (!mounted) return;
      setState(() => _size = actual);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    _rebuilds++;
    final colors = context.lattice.colors;
    return Column(
      children: [
        _buildHeader(colors),
        Divider(height: 1, color: colors.border),
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInfoCard(colors),
                const SizedBox(height: 12),
                _buildProportionalImage(colors),
                const SizedBox(height: 12),
                _buildLiveWidthReadout(colors),
                const SizedBox(height: 12),
                _buildReflowTags(colors),
                const SizedBox(height: 12),
                _buildReadinessSlider(colors),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: colors.border),
        _buildControlBar(colors),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(LatticeColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(Icons.aspect_ratio, color: colors.accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Panel Resize Demo',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _SizeBadge(size: _size, busy: _busy),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card: icon on the left, text box on the right
  // ---------------------------------------------------------------------------

  Widget _buildInfoCard(LatticeColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.borderActive),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.edit_note, color: colors.accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _noteController,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Type a note, then resize…',
                hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: colors.accent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Proportional image: anchored left + right, grows taller with the width
  // ---------------------------------------------------------------------------

  Widget _buildProportionalImage(LatticeColorScheme colors) {
    // AspectRatio inside a stretched column: image fills the panel width and its height scales proportionally.
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.surfaceElevated,
                    colors.surface,
                  ],
                ),
              ),
            ),
            Center(
              child: Image.asset(
                'assets/logo.png',
                package: 'panel_resize_demo',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.image, color: colors.textMuted, size: 48),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 6,
              child: Text(
                '16:9 — grows taller as the panel widens',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Live width readout — the clearest proof that a resize re-lays-out the panel
  // ---------------------------------------------------------------------------

  Widget _buildLiveWidthReadout(LatticeColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      // LayoutBuilder gets fresh constraints on every width animation frame, so the readout ticks live.
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              Icon(Icons.straighten, size: 16, color: colors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Content width: ${constraints.maxWidth.toStringAsFixed(0)} px',
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                ),
              ),
              Text(
                'rebuilds: $_rebuilds',
                style: TextStyle(color: colors.textMuted, fontSize: 11),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Reflowing tag chips — re-wrap across rows as the width changes
  // ---------------------------------------------------------------------------

  Widget _buildReflowTags(LatticeColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TAGS (reflow on resize)',
          style: TextStyle(
            color: colors.textLabel,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _tags.map((tag) {
            final selected = _selectedTags.contains(tag);
            return FilterChip(
              label: Text(tag),
              selected: selected,
              onSelected: (on) => setState(() {
                if (on) {
                  _selectedTags.add(tag);
                } else {
                  _selectedTags.remove(tag);
                }
              }),
              selectedColor: colors.accent,
              backgroundColor: colors.surface,
              labelStyle: TextStyle(
                color: selected ? colors.onAccent : colors.textSecondary,
                fontSize: 12,
              ),
              side: BorderSide(color: colors.border),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Slider — a control whose track stretches with the panel width
  // ---------------------------------------------------------------------------

  Widget _buildReadinessSlider(LatticeColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'READINESS: ${(_readiness * 100).round()}%',
          style: TextStyle(
            color: colors.textLabel,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        Slider(
          value: _readiness,
          activeColor: colors.accent,
          onChanged: (v) => setState(() => _readiness = v),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom control bar — fixed-size, left-anchored, does not grow with panel
  // ---------------------------------------------------------------------------

  Widget _buildControlBar(LatticeColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        // Trailing Spacer absorbs extra width so buttons stay left-anchored at fixed size.
        children: [
          _ControlButton(
            icon: Icons.arrow_left,
            tooltip: 'Grow panel',
            onPressed: (_busy || _size == _order.last) ? null : _grow,
            colors: colors,
          ),
          const SizedBox(width: 8),
          _ControlButton(
            icon: Icons.arrow_right,
            tooltip: 'Shrink panel',
            onPressed: (_busy || _size == _order.first) ? null : _shrink,
            colors: colors,
          ),
          const SizedBox(width: 8),
          _ControlButton(
            icon: Icons.restart_alt,
            tooltip: 'Reset to smallest',
            onPressed: _busy ? null : _resetToSmallest,
            colors: colors,
          ),
          if (_hint != null) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                _hint!,
                style: TextStyle(color: colors.textMuted, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const Spacer(),
        ],
      ),
    );
  }
}

/// Small pill showing the panel's current preset size.
class _SizeBadge extends StatelessWidget {
  final PanelSize size;
  final bool busy;
  const _SizeBadge({required this.size, required this.busy});

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.borderActive),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: colors.accent,
              ),
            )
          else
            Icon(Icons.crop, size: 12, color: colors.accent),
          const SizedBox(width: 5),
          Text(
            size.name.toUpperCase(),
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fixed 48×48 control button used in the bottom bar. Glove-friendly target,
/// fixed size so it never grows with the panel.
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final LatticeColorScheme colors;

  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Material(
          color: enabled ? colors.surface : colors.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.borderActive),
              ),
              child: Icon(
                icon,
                size: 24,
                color: enabled ? colors.textPrimary : colors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
