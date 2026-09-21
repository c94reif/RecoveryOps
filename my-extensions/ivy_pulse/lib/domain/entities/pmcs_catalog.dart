import 'package:ivy_pulse/domain/entities/pmcs_category.dart';
import 'package:ivy_pulse/domain/entities/pmcs_check_item.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';

/// The complete set of TM PMCS checks for one vehicle platform, keyed by phase.
class PmcsCatalog {
  final VehicleType vehicleType;
  final Map<PmcsPhase, List<PmcsCategory>> phases;

  const PmcsCatalog({
    required this.vehicleType,
    required this.phases,
  });

  List<PmcsCategory> categoriesFor(PmcsPhase phase) =>
      phases[phase] ?? const [];

  /// Every check in a phase, flattened in TM walk-around order.
  List<PmcsCheckItem> itemsFor(PmcsPhase phase) => [
        for (final category in categoriesFor(phase)) ...category.items,
      ];

  int itemCountFor(PmcsPhase phase) {
    var total = 0;
    for (final category in categoriesFor(phase)) {
      total += category.items.length;
    }
    return total;
  }

  int get totalItemCount {
    var total = 0;
    for (final phase in PmcsPhase.values) {
      total += itemCountFor(phase);
    }
    return total;
  }

  PmcsCheckItem? findItem(String itemId) {
    for (final phase in PmcsPhase.values) {
      for (final category in categoriesFor(phase)) {
        for (final item in category.items) {
          if (item.id == itemId) return item;
        }
      }
    }
    return null;
  }

  /// The station/system an item belongs to, used to label a fault on the 5988-E.
  String? categoryNameFor(String itemId) {
    for (final phase in PmcsPhase.values) {
      for (final category in categoriesFor(phase)) {
        for (final item in category.items) {
          if (item.id == itemId) return category.name;
        }
      }
    }
    return null;
  }
}
