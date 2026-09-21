import 'package:ivy_pulse/domain/entities/check_result.dart';
import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/pmcs_category.dart';
import 'package:ivy_pulse/domain/entities/pmcs_check_item.dart';
import 'package:ivy_pulse/domain/entities/pmcs_fault.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';

/// The answers for the one phase the operator is standing in, plus the counts
/// the header and the complete-phase button read off them.
///
/// Separate from the session because it has a different lifetime: it is built
/// when a phase opens, discarded when the phase closes, and never outlives the
/// walk-around — the durable copy is already in the database by then.
class PhaseWorkspace {
  final PmcsPhase phase;
  final List<PmcsCategory> categories;

  /// Answers so far, keyed by TM item id.
  final Map<String, CheckResult> results;

  /// The one check open at full size. Everything else sits as a single row.
  ///
  /// The extension runs in a side panel barely 370 logical pixels tall in
  /// landscape, so a list of expanded cards buries the check the operator is
  /// actually standing at. Exactly one is open at a time, and it is the one
  /// they are on.
  String? expandedItemId;

  PhaseWorkspace({
    required this.phase,
    required this.categories,
    Map<String, CheckResult>? results,
  }) : results = {...?results} {
    expandedItemId = nextUnansweredItemId;
  }

  /// Every check in the phase, in TM walk-around order.
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

  /// The next check still owed, in TM order — what the page scrolls to.
  String? get nextUnansweredItemId {
    for (final item in items) {
      if (!results.containsKey(item.id)) return item.id;
    }
    return null;
  }

  /// Severity counts straight off the answers: faults are only written out
  /// when the phase is closed, so this is the only live view of them.
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

  /// Every check that is not the open one — what the page folds to a row.
  Set<String> get collapsedItemIds => {
        for (final item in items)
          if (item.id != expandedItemId) item.id,
      };

  /// Records an answer and moves the open card to the next check still owed,
  /// so answering one check hands the operator the next without a scroll.
  void record(CheckResult result) {
    results[result.itemId] = result;
    expandedItemId = nextUnansweredItemId;
  }

  void expand(String itemId) => expandedItemId = itemId;

  void collapse(String itemId) {
    if (expandedItemId == itemId) expandedItemId = null;
  }
}
