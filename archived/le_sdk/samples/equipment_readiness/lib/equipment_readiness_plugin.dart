import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';

import 'config.dart';
import 'report_state.dart';

class EquipmentReadinessPlugin extends LatticeEdgeExtension {
  @override
  String get id => 'equipment_readiness';

  @override
  String get name => 'Equipment Readiness';

  @override
  String get description => 'Report equipment readiness status (FMC/PMC/NMC)';

  @override
  IconData get icon => Icons.build_circle;

  @override
  String? get iconAsset => 'assets/logo.png';

  @override
  ExtensionDisplayMode get defaultDisplayMode => ExtensionDisplayMode.panel;

  @override
  Widget build(ExtensionContext context) =>
      _EquipmentReadinessApp(context: context);
}

enum _AppScreen {
  home,
  selectUnit,
  selectSite,
  browseEquipment,
  enterStatus,
  review,
  success,
  history,
  historyDetail,
}

class _EquipmentReadinessApp extends StatefulWidget {
  final ExtensionContext context;
  const _EquipmentReadinessApp({required this.context});

  @override
  State<_EquipmentReadinessApp> createState() =>
      _EquipmentReadinessAppState();
}

class _EquipmentReadinessAppState extends State<_EquipmentReadinessApp> {
  EquipmentConfig? _config;
  _AppScreen _screen = _AppScreen.home;
  _AppScreen? _previousScreen;

  UnitInfo? _selectedUnit;
  SiteInfo? _selectedSite;
  String? _activeSitePolylineId;

  // Report building state
  final Map<String, EquipmentStatus> _reportItems = {};
  String? _currentEquipmentId;

  // Favorites (persisted)
  final Set<String> _favorites = {};

  // History (persisted)
  final List<SavedReport> _savedReports = [];
  int? _selectedReportIndex;

  // Search/filter state
  String _unitSearch = '';
  String _equipmentSearch = '';
  bool _showFavorites = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadFavorites();
    _loadHistory();
  }

  Future<void> _loadConfig() async {
    final raw = await rootBundle.loadString(
        'packages/equipment_readiness/assets/equipment_readiness_config.json');
    setState(() {
      _config = EquipmentConfig.fromJson(jsonDecode(raw));
      // Default to first unit and first available site
      if (_config!.allUnits.isNotEmpty) {
        _selectedUnit = _config!.allUnits.first;
        final sites = _config!.sitesForUnit(_selectedUnit!);
        if (sites.isNotEmpty) {
          _selectSite(sites.first);
        }
      }
    });
  }

  Future<void> _loadFavorites() async {
    final raw = await widget.context.storage.read('equipment_readiness_favorites');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        setState(() => _favorites.addAll(list.cast<String>()));
      } catch (_) {}
    }
  }

  Future<void> _persistFavorites() async {
    await widget.context.storage.write(
      'equipment_readiness_favorites',
      jsonEncode(_favorites.toList()),
    );
  }

  Future<void> _loadHistory() async {
    final raw = await widget.context.storage.read('equipment_readiness_history');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        setState(() {
          _savedReports.addAll(
            list.map((e) => SavedReport.fromJson(e as Map<String, dynamic>)),
          );
        });
      } catch (_) {}
    }
  }

  Future<void> _persistHistory() async {
    await widget.context.storage.write(
      'equipment_readiness_history',
      jsonEncode(_savedReports.map((r) => r.toJson()).toList()),
    );
  }

  Future<void> _selectSite(SiteInfo site) async {
    // Remove previous polyline
    if (_activeSitePolylineId != null) {
      try {
        await widget.context.map.removePolyline(_activeSitePolylineId!);
      } catch (_) {}
    }

    setState(() {
      _selectedSite = site;
      _activeSitePolylineId = 'site_boundary_${site.id}';
    });

    // Draw boundary polyline — close the polygon by repeating the first point
    final points = [...site.boundary];
    if (points.isNotEmpty) {
      points.add(points.first);
    }
    await widget.context.map.addPolyline(
      _activeSitePolylineId!,
      points,
      color: LatticeColorScheme.dark.accent.toHex(),
    );

    // Fly to site center
    await widget.context.map.flyTo(site.center, zoom: 11.0);
  }

  void _resetReport() {
    _reportItems.clear();
    _currentEquipmentId = null;
  }

  void _toggleFavorite(String itemId) {
    setState(() {
      if (_favorites.contains(itemId)) {
        _favorites.remove(itemId);
      } else {
        _favorites.add(itemId);
      }
    });
    _persistFavorites();
  }

  // ── UI Helpers ──

  Color _parseColor(String? hex, {Color? fallback}) {
    final fb = fallback ?? LatticeColorScheme.dark.accent;
    if (hex == null || hex.isEmpty) return fb;
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    if (value == null) return fb;
    return Color(0xFF000000 | value);
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    if (_config == null) {
      return Center(
        child: CircularProgressIndicator(color: colors.accent),
      );
    }

    return Column(
      children: [
        // Persistent unit/site selector bar
        _buildSelectorBar(colors),
        // Screen body
        Expanded(child: _buildScreen(colors)),
      ],
    );
  }

  Widget _buildSelectorBar(LatticeColorScheme colors) {
    final unitColor = _selectedUnit != null
        ? _parseColor(_selectedUnit!.color ??
            (_selectedUnit!.parentUic != null
                ? _config!.units
                    .where((u) => u.uic == _selectedUnit!.parentUic)
                    .firstOrNull
                    ?.color
                : null), fallback: colors.accent)
        : colors.accent;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.borderActive)),
      ),
      child: Row(
        children: [
          // Unit selector
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                if (_screen == _AppScreen.selectUnit) {
                  _screen = _previousScreen ?? _AppScreen.home;
                  _previousScreen = null;
                } else {
                  _previousScreen = _screen;
                  _screen = _AppScreen.selectUnit;
                }
                _unitSearch = '';
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: colors.borderActive)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: unitColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedUnit?.name ?? 'Select Unit',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      _screen == _AppScreen.selectUnit
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 16,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Site selector
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                if (_screen == _AppScreen.selectSite) {
                  _screen = _previousScreen ?? _AppScreen.home;
                  _previousScreen = null;
                } else {
                  _previousScreen = _screen;
                  _screen = _AppScreen.selectSite;
                }
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 12, color: colors.statusActive),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedSite?.name ?? 'Select Site',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      _screen == _AppScreen.selectSite
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 16,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreen(LatticeColorScheme colors) {
    return switch (_screen) {
      _AppScreen.home => _buildHomeScreen(colors),
      _AppScreen.selectUnit => _buildSelectUnitScreen(colors),
      _AppScreen.selectSite => _buildSelectSiteScreen(colors),
      _AppScreen.browseEquipment => _buildBrowseEquipmentScreen(colors),
      _AppScreen.enterStatus => _buildEnterStatusScreen(colors),
      _AppScreen.review => _buildReviewScreen(colors),
      _AppScreen.success => _buildSuccessScreen(colors),
      _AppScreen.history => _buildHistoryScreen(colors),
      _AppScreen.historyDetail => _buildHistoryDetailScreen(colors),
    };
  }

  // ── Home Screen ──

  Widget _buildHomeScreen(LatticeColorScheme colors) {
    return ClipRect(child: ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _resetReport();
            _screen = _AppScreen.browseEquipment;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              border: Border.all(color: colors.borderActive),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.build, color: colors.textPrimary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('New Report',
                          style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text('Equipment readiness status',
                          style:
                              TextStyle(color: colors.textLabel, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: colors.inactive, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _screen = _AppScreen.history),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              border: Border.all(color: colors.borderActive),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.history,
                      color: colors.textLabel, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Report History',
                          style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '${_savedReports.length} report${_savedReports.length == 1 ? '' : 's'} sent',
                        style: TextStyle(
                            color: colors.textLabel, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: colors.inactive, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'Last synced: ${_formatDate(DateTime.now())}',
            style: TextStyle(color: colors.inactive, fontSize: 12),
          ),
        ),
      ],
    ));
  }

  // ── Select Unit Screen ──

  Widget _buildSelectUnitScreen(LatticeColorScheme colors) {
    final allUnits = _config!.allUnits;
    final filtered = _unitSearch.isEmpty
        ? allUnits
        : allUnits
            .where((u) =>
                u.name.toLowerCase().contains(_unitSearch.toLowerCase()) ||
                u.uic.toLowerCase().contains(_unitSearch.toLowerCase()))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text('Select Unit',
                    style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _screen = _previousScreen ?? _AppScreen.home;
                  _previousScreen = null;
                }),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surfaceElevated,
                  ),
                  child: Icon(Icons.close,
                      size: 16, color: colors.textLabel),
                ),
              ),
            ],
          ),
        ),
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              border: Border.all(color: colors.borderActive),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _unitSearch = v),
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by UIC or unit name...',
                hintStyle: TextStyle(color: colors.inactive, fontSize: 14),
                prefixIcon:
                    Icon(Icons.search, color: colors.inactive, size: 18),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Unit list
        Expanded(
          child: ClipRect(
            child: ListView.builder(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final unit = filtered[i];
              final isSelected = unit.uic == _selectedUnit?.uic;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedUnit = unit;
                      // Check if current site is still valid
                      final validSites = _config!.sitesForUnit(unit);
                      if (_selectedSite != null &&
                          !validSites.any((s) => s.id == _selectedSite!.id)) {
                        _selectedSite = null;
                        // Auto-select first available site
                        if (validSites.isNotEmpty) {
                          _selectSite(validSites.first);
                        }
                      }
                      _screen = _previousScreen ?? _AppScreen.home;
                      _previousScreen = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      border: Border.all(
                        color: isSelected
                            ? colors.accent
                            : colors.borderActive,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                unit.name,
                                style: TextStyle(
                                  color: isSelected
                                      ? colors.accent
                                      : colors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'UIC: ${unit.uic}',
                                style: TextStyle(
                                  color: isSelected
                                      ? colors.textSecondary
                                      : colors.inactive,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check,
                              color: colors.accent, size: 18),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          ),
        ),
      ],
    );
  }

  // ── Select Site Screen ──

  Widget _buildSelectSiteScreen(LatticeColorScheme colors) {
    final sites = _selectedUnit != null
        ? _config!.sitesForUnit(_selectedUnit!)
        : <SiteInfo>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text('Select Site',
                    style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _screen = _previousScreen ?? _AppScreen.home;
                  _previousScreen = null;
                }),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surfaceElevated,
                  ),
                  child: Icon(Icons.close,
                      size: 16, color: colors.textLabel),
                ),
              ),
            ],
          ),
        ),
        if (sites.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No sites available for selected unit.',
                style: TextStyle(color: colors.inactive, fontSize: 14)),
          )
        else
          Expanded(
            child: ClipRect(
              child: ListView.builder(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: sites.length,
              itemBuilder: (ctx, i) {
                final site = sites[i];
                final isSelected = site.id == _selectedSite?.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GestureDetector(
                    onTap: () {
                      _selectSite(site);
                      setState(() {
                        _screen = _previousScreen ?? _AppScreen.home;
                        _previousScreen = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        border: Border.all(
                          color: isSelected
                              ? colors.accent
                              : colors.borderActive,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            site.name,
                            style: TextStyle(
                              color: isSelected
                                  ? colors.accent
                                  : colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isSelected) ...[
                            const Spacer(),
                            Icon(Icons.check,
                                color: colors.accent, size: 18),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            ),
          ),
      ],
    );
  }

  // ── Browse Equipment Screen ──

  Widget _buildBrowseEquipmentScreen(LatticeColorScheme colors) {
    return Column(
      children: [
        // Header with inline tabs
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _screen = _AppScreen.home),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Icon(Icons.arrow_back, color: colors.textLabel, size: 20),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showFavorites = true),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: _showFavorites
                        ? colors.accent
                        : colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '☆ Favorites',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight:
                          _showFavorites ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _showFavorites = false),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: !_showFavorites
                        ? colors.accent
                        : colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'All Equipment',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight:
                          !_showFavorites ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Search bar (All tab only)
        if (!_showFavorites)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                border: Border.all(color: colors.borderActive),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _equipmentSearch = v),
                style: TextStyle(color: colors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search NSN, name...',
                  hintStyle: TextStyle(color: colors.inactive, fontSize: 14),
                  prefixIcon:
                      Icon(Icons.search, color: colors.inactive, size: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        // Item list
        Expanded(
          child: ClipRect(
            child: _showFavorites
                ? _buildFavoritesTab(colors)
                : _buildAllEquipmentTab(colors),
          ),
        ),
        // Review button (shown when items have been added)
        if (_reportItems.values.any((s) => !s.isEmpty))
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () => setState(() => _screen = _AppScreen.review),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Review (${_reportItems.values.where((s) => !s.isEmpty).length})',
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAllEquipmentTab(LatticeColorScheme colors) {
    final categories = _config!.categories;
    final searchQuery = _equipmentSearch.toLowerCase();

    final children = <Widget>[];
    for (final cat in categories) {
      final filteredItems = searchQuery.isEmpty
          ? cat.items
          : cat.items
              .where((item) =>
                  item.name.toLowerCase().contains(searchQuery) ||
                  item.nsn.toLowerCase().contains(searchQuery))
              .toList();
      if (filteredItems.isNotEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            cat.name.toUpperCase(),
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ));
        for (final item in filteredItems) {
          children.add(_buildEquipmentCard(item, colors));
        }
      }
    }

    return ClipRect(child: ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: children,
    ));
  }

  Widget _buildFavoritesTab(LatticeColorScheme colors) {
    final categories = _config!.categories;
    final hasFavorites = categories.any(
        (cat) => cat.items.any((item) => _favorites.contains(item.id)));

    if (!hasFavorites) {
      return Center(
        child: Text(
          'No favorites yet.\nStar items to add them here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.inactive, fontSize: 14),
        ),
      );
    }

    final children = <Widget>[];
    for (final cat in categories) {
      final favItems =
          cat.items.where((item) => _favorites.contains(item.id)).toList();
      if (favItems.isNotEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            cat.name.toUpperCase(),
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ));
        for (final item in favItems) {
          children.add(_buildEquipmentCard(item, colors));
        }
      }
    }

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: children,
    );
  }

  Widget _buildEquipmentCard(EquipmentItem item, LatticeColorScheme colors) {
    final isFav = _favorites.contains(item.id);
    final hasStatus = _reportItems.containsKey(item.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentEquipmentId = item.id;
            // Initialize status if not already present
            _reportItems.putIfAbsent(
                item.id, () => EquipmentStatus(equipmentId: item.id));
            _screen = _AppScreen.enterStatus;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            border: Border.all(
              color: hasStatus
                  ? const Color(0xFF2A4A2A) // domain: completed item indicator
                  : colors.borderActive,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _toggleFavorite(item.id),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Text(
                      isFav ? '★' : '☆',
                      style: TextStyle(
                        fontSize: 18,
                        color: isFav
                            ? const Color(0xFFFFD700)
                            : colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('NSN: ${item.nsn}',
                        style: TextStyle(
                            color: colors.inactive, fontSize: 12)),
                  ],
                ),
              ),
              if (hasStatus)
                const Icon(Icons.check_circle,
                    color: Color(0xFF4ADE80), size: 16),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  color: colors.inactive, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── Enter Status Screen ──

  Widget _buildEnterStatusScreen(LatticeColorScheme colors) {
    if (_currentEquipmentId == null) {
      return const SizedBox.shrink();
    }
    final item = _config!.findItem(_currentEquipmentId!);
    if (item == null) return const SizedBox.shrink();
    final status = _reportItems[item.id]!;
    final isFav = _favorites.contains(item.id);

    return ClipRect(
      child: ListView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (status.isEmpty) {
                      _reportItems.remove(item.id);
                    }
                    setState(() => _screen = _AppScreen.browseEquipment);
                  },
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Icon(Icons.arrow_back,
                          color: colors.textLabel, size: 20),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(item.name,
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                GestureDetector(
                  onTap: () => _toggleFavorite(item.id),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Text(
                        isFav ? '★' : '☆',
                        style: TextStyle(
                          fontSize: 20,
                          color: isFav
                              ? const Color(0xFFFFD700)
                              : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Status sections
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildStatusSection(
              label: 'FMC — Fully Mission Capable',
              color: const Color(0xFF4ADE80),
              value: status.fmc,
              onChanged: (v) => setState(() => status.fmc = v),
              colors: colors,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildStatusSection(
              label: 'PMC — Partially Mission Capable',
              color: const Color(0xFFFACC15),
              value: status.pmc,
              onChanged: (v) => setState(() => status.pmc = v),
              colors: colors,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildStatusSection(
              label: 'NMC — Not Mission Capable',
              color: const Color(0xFFF87171),
              value: status.nmc,
              onChanged: (v) => setState(() => status.nmc = v),
              colors: colors,
            ),
          ),
          // Confirm button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: GestureDetector(
              onTap: () {
                if (status.isEmpty) {
                  _reportItems.remove(item.id);
                }
                setState(() => _screen = _AppScreen.browseEquipment);
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Confirm Status',
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection({
    required String label,
    required Color color,
    required int value,
    required ValueChanged<int> onChanged,
    required LatticeColorScheme colors,
  }) {
    final darkColor = Color.lerp(color, Colors.black, 0.7)!;
    final darkRed = const Color(0xFF3A1A1A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '$value',
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: 36,
                fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        // +/-10 row
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(max(0, value - 10)),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    border: Border.all(color: colors.borderActive),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text('-10',
                      style: TextStyle(color: colors.textPrimary, fontSize: 14)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(value + 10),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: darkColor,
                    border: Border.all(color: color),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text('+10',
                      style: TextStyle(color: color, fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // +/-1 row
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(max(0, value - 1)),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: darkRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text('-',
                      style: TextStyle(
                          color: Color(0xFFF87171),
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(value + 1),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: darkColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text('+',
                      style: TextStyle(
                          color: color,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Review Screen ──

  Widget _buildReviewScreen(LatticeColorScheme colors) {
    final filledItems = _reportItems.entries
        .where((e) => !e.value.isEmpty)
        .toList();

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () =>
                    setState(() => _screen = _AppScreen.browseEquipment),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Icon(Icons.arrow_back,
                        color: colors.textLabel, size: 20),
                  ),
                ),
              ),
              Text('Review Report',
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        // Context bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _parseColor(_selectedUnit?.color),
                ),
              ),
              const SizedBox(width: 8),
              Text(_selectedUnit?.name ?? '',
                  style: TextStyle(
                      color: colors.textLabel, fontSize: 13)),
              const SizedBox(width: 8),
              Text('·',
                  style: TextStyle(color: colors.borderActive)),
              const SizedBox(width: 8),
              const Icon(Icons.location_on,
                  size: 12, color: Color(0xFF4A9EFF)),
              const SizedBox(width: 4),
              Text(_selectedSite?.name ?? '',
                  style: TextStyle(
                      color: colors.textLabel, fontSize: 13)),
              const Spacer(),
              Text('${filledItems.length} items',
                  style: TextStyle(
                      color: colors.textLabel, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Info banner
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2A3A),
              border: Border.all(color: const Color(0xFF2A4A6A)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: Color(0xFF6AA8F0)),
                const SizedBox(width: 8),
                Text(
                  'Only ${filledItems.length} item${filledItems.length == 1 ? '' : 's'} below will be submitted.',
                  style: const TextStyle(
                      color: Color(0xFF6AA8F0), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Item cards
        Expanded(
          child: ClipRect(
            child: ListView.builder(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filledItems.length,
              itemBuilder: (ctx, i) {
                final entry = filledItems[i];
                final item = _config!.findItem(entry.key);
                if (item == null) return const SizedBox.shrink();
                final status = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      border:
                          Border.all(color: const Color(0xFF2A4A2A)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check,
                                color: Color(0xFF4ADE80), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(item.name,
                                  style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                _reportItems.remove(entry.key);
                              }),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3A1A1A),
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.delete_outline,
                                    color: Color(0xFFF87171), size: 16),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _statusBadge(
                                status.fmc, 'FMC', const Color(0xFF4ADE80), colors),
                            const SizedBox(width: 12),
                            _statusBadge(
                                status.pmc, 'PMC', const Color(0xFFFACC15), colors),
                            const SizedBox(width: 12),
                            _statusBadge(
                                status.nmc, 'NMC', const Color(0xFFF87171), colors),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Bottom actions
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _screen = _AppScreen.browseEquipment),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      border: Border.all(color: colors.borderActive),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text('+ Add More',
                        style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: filledItems.isEmpty ? null : _sendReport,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: filledItems.isEmpty
                          ? colors.borderActive
                          : colors.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Send (${filledItems.length})',
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(int count, String label, Color color, LatticeColorScheme colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$count',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(color: colors.textSecondary, fontSize: 13)),
      ],
    );
  }

  // ── Send Flow ──

  Future<void> _sendReport() async {
    final filledItems = _reportItems.entries
        .where((e) => !e.value.isEmpty)
        .map((e) => e.value)
        .toList();

    if (filledItems.isEmpty) return;

    // Pick recipients
    final recipients = await widget.context.messaging.pickRecipients();
    if (recipients == null || recipients.isEmpty) return;

    // Build payload
    final payload = jsonEncode({
      'type': 'equipment_readiness',
      'unit': _selectedUnit?.name,
      'site': _selectedSite?.name,
      'items': filledItems.map((s) => {
            'equipmentId': s.equipmentId,
            'name': _config!.findItem(s.equipmentId)?.name ?? s.equipmentId,
            'fmc': s.fmc,
            'pmc': s.pmc,
            'nmc': s.nmc,
          }).toList(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    // Send
    await widget.context.messaging.sendToMultiple(
      recipients.map((p) => p.deviceId).toList(),
      payload,
    );

    // Save to history
    final report = SavedReport(
      unitName: _selectedUnit?.name ?? '',
      siteName: _selectedSite?.name ?? '',
      items: filledItems.map((s) => EquipmentStatus(
            equipmentId: s.equipmentId,
            fmc: s.fmc,
            pmc: s.pmc,
            nmc: s.nmc,
          )).toList(),
      timestamp: DateTime.now(),
      recipientNames: recipients.map((p) => p.callsign).toList(),
    );
    _savedReports.insert(0, report);
    _persistHistory();

    setState(() => _screen = _AppScreen.success);
  }

  // ── Success Screen ──

  Widget _buildSuccessScreen(LatticeColorScheme colors) {
    final filledCount =
        _reportItems.values.where((s) => !s.isEmpty).length;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4ADE80),
              ),
              child: Icon(Icons.check, color: colors.textPrimary, size: 36),
            ),
            const SizedBox(height: 20),
            Text('Report Sent',
                style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              '$filledCount items · ${_selectedUnit?.name ?? ''} · ${_selectedSite?.name ?? ''}',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () {
                _resetReport();
                setState(() => _screen = _AppScreen.home);
              },
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  border: Border.all(color: colors.borderActive),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text('New Report',
                    style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── History Screen ──

  Widget _buildHistoryScreen(LatticeColorScheme colors) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _screen = _AppScreen.home),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Icon(Icons.arrow_back,
                        color: colors.textLabel, size: 20),
                  ),
                ),
              ),
              Text('Report History',
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (_savedReports.isEmpty)
          Expanded(
            child: Center(
              child: Text('No reports sent yet.',
                  style: TextStyle(color: colors.inactive, fontSize: 14)),
            ),
          )
        else
          Expanded(
            child: ClipRect(
              child: ListView.builder(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _savedReports.length,
                itemBuilder: (ctx, i) {
                  final report = _savedReports[i];
                  final dateStr = _formatDate(report.timestamp);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedReportIndex = i;
                        _screen = _AppScreen.historyDetail;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated,
                          border: Border.all(
                              color: colors.borderActive),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${report.unitName} · ${report.siteName}',
                                    style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  '${report.items.length} items',
                                  style: TextStyle(
                                      color: colors.inactive,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$dateStr · Sent to ${report.recipientNames.join(', ')}',
                              style: TextStyle(
                                  color: colors.textSecondary, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  // ── History Detail Screen ──

  Widget _buildHistoryDetailScreen(LatticeColorScheme colors) {
    if (_selectedReportIndex == null ||
        _selectedReportIndex! >= _savedReports.length) {
      return const SizedBox.shrink();
    }
    final report = _savedReports[_selectedReportIndex!];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _screen = _AppScreen.history),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Icon(Icons.arrow_back,
                        color: colors.textLabel, size: 20),
                  ),
                ),
              ),
              Expanded(
                child: Text('Report Detail',
                    style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              Text(_formatDate(report.timestamp),
                  style: TextStyle(
                      color: colors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        // Context bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.location_on,
                  size: 12, color: Color(0xFF4A9EFF)),
              const SizedBox(width: 4),
              Text('${report.unitName} · ${report.siteName}',
                  style: TextStyle(
                      color: colors.textLabel, fontSize: 13)),
              const Spacer(),
              Text('${report.items.length} items',
                  style: TextStyle(
                      color: colors.textLabel, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ClipRect(
            child: ListView.builder(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: report.items.length,
              itemBuilder: (ctx, i) {
                final status = report.items[i];
                final item = _config?.findItem(status.equipmentId);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      border:
                          Border.all(color: colors.borderActive),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item?.name ?? status.equipmentId,
                          style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _statusBadge(status.fmc, 'FMC',
                                const Color(0xFF4ADE80), colors),
                            const SizedBox(width: 12),
                            _statusBadge(status.pmc, 'PMC',
                                const Color(0xFFFACC15), colors),
                            const SizedBox(width: 12),
                            _statusBadge(status.nmc, 'NMC',
                                const Color(0xFFF87171), colors),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Sent to
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Sent to: ${report.recipientNames.join(', ')}',
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year} $h:${m}Z';
  }
}
