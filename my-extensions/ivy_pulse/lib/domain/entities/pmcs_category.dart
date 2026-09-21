import 'package:ivy_pulse/domain/entities/pmcs_check_item.dart';

/// A walk-around station or vehicle system grouping several TM checks —
/// e.g. `ENGINE COMPARTMENT` or `DRIVER SIDE FRONT`.
class PmcsCategory {
  final String name;
  final List<PmcsCheckItem> items;

  const PmcsCategory({
    required this.name,
    required this.items,
  });

  int get itemCount => items.length;
}
