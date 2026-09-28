import 'package:ivy_pulse/domain/entities/check_result.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_category.dart';
import 'package:ivy_pulse/domain/entities/pmcs_check_item.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';

class PhaseWorkspace {
  final PmcsPhase phase;
  final List<PmcsCategory> categories;

  final Map<String, CheckResult> results;

  String? expandedItemId;

  PhaseWorkspace({
    required this.phase,
    required this.categories,
    Map<String, CheckResult>? results,
  }) : results = {...?results} {
    expandedItemId = nextUnansweredItemId;
  }

  List<PmcsCheckItem> get items => [
        for (final category in categories) ...category.items,
      ];

  int get totalCount => items.length;

  int get answeredCount {
    var answered = 0;
    for (final item in items) {
      if (results.containsKey(item.id)) answered++;
    }
    return answered;
  }

  bool get isComplete => totalCount > 0 && answeredCount == totalCount;

  String? get nextUnansweredItemId {
    for (final item in items) {
      if (!results.containsKey(item.id)) return item.id;
    }
    return null;
  }

  FaultTally get tally {
    var redX = 0;
    var circleX = 0;
    var dash = 0;
    for (final result in results.values) {
      final severity = result.severity;
      if (severity == null) continue;
      switch (severity) {
        case FaultSeverity.redX:
          redX++;
        case FaultSeverity.circleX:
          circleX++;
        case FaultSeverity.dash:
          dash++;
      }
    }
    return FaultTally(redX: redX, circleX: circleX, dash: dash);
  }

  CheckResult? resultFor(String itemId) => results[itemId];

  bool isExpanded(String itemId) => expandedItemId == itemId;

  Set<String> get collapsedItemIds => {
        for (final item in items)
          if (item.id != expandedItemId) item.id,
      };

  void record(CheckResult result) {
    results[result.itemId] = result;
    expandedItemId = nextUnansweredItemId;
  }

  void expand(String itemId) => expandedItemId = itemId;

  void collapse(String itemId) {
    if (expandedItemId == itemId) expandedItemId = null;
  }
}
