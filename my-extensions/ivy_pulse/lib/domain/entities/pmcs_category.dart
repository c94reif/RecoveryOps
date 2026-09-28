import 'package:ivy_pulse/domain/entities/pmcs_check_item.dart';

class PmcsCategory {
  final String name;
  final List<PmcsCheckItem> items;

  const PmcsCategory({
    required this.name,
    required this.items,
  });

  int get itemCount => items.length;
}
