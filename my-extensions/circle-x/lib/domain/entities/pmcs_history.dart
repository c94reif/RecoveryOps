import 'dart:convert';

import 'package:circle_x/domain/entities/pmcs_fault.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/domain/entities/pmcs_report.dart';
import 'package:circle_x/domain/entities/vehicle_type.dart';

class HistoricalFault {
  final PmcsReport report;
  final PmcsFault fault;

  const HistoricalFault(this.report, this.fault);

  String get suggestionId =>
      jsonEncode([report.entityId, fault.phase.wireName, fault.itemId]);
}

enum FaultChangeKind { newFault, recurring, changed, noLongerReported }

class FaultChange {
  final FaultChangeKind kind;
  final PmcsFault? previous;
  final PmcsFault? current;

  const FaultChange(this.kind, {this.previous, this.current});

  PmcsFault get fault => current ?? previous!;
}

class PhaseComparison {
  final PmcsPhase phase;
  final PmcsReport? previous;
  final List<FaultChange> changes;

  const PhaseComparison(this.phase, this.previous, this.changes);
}

class PmcsHistory {
  final List<PmcsReport> reports;

  PmcsHistory.forVehicle(
    Iterable<PmcsReport> source, {
    required String bumperNumber,
    required String uic,
    required VehicleType vehicleType,
    DateTime? before,
    String? excluding,
  }) : reports = source
            .where((report) =>
                !report.isMaintainerReview &&
                report.entityId != excluding &&
                report.vehicleType == vehicleType &&
                _normalize(report.bumperNumber) == _normalize(bumperNumber) &&
                _normalize(report.uic) == _normalize(uic) &&
                (before == null || report.timestamp.isBefore(before)))
            .toList()
          ..sort((first, second) {
            final timestampOrder = second.timestamp.compareTo(first.timestamp);
            return timestampOrder != 0
                ? timestampOrder
                : second.entityId.compareTo(first.entityId);
          });

  static String _normalize(String value) => value.trim().toUpperCase();

  PmcsReport? previousFor(PmcsPhase phase) {
    for (final report in reports) {
      if (report.phases.contains(phase)) return report;
    }
    return null;
  }

  List<HistoricalFault> get suggestedUnresolved {
    final coveredPhases = <PmcsPhase>{};
    final seenFaultKeys = <(PmcsPhase, String)>{};
    final suggestions = <HistoricalFault>[];
    for (final report in reports) {
      for (final fault in report.faults) {
        if (!coveredPhases.contains(fault.phase) &&
            seenFaultKeys.add((fault.phase, fault.itemId))) {
          suggestions.add(HistoricalFault(report, fault));
        }
      }
      coveredPhases.addAll(report.phases);
    }
    suggestions.sort((first, second) =>
        second.fault.severity.rank.compareTo(first.fault.severity.rank));
    return suggestions;
  }

  HistoricalFault? previousFault(PmcsPhase phase, String itemId) {
    for (final suggestion in suggestedUnresolved) {
      if (suggestion.fault.phase == phase &&
          suggestion.fault.itemId == itemId) {
        return suggestion;
      }
    }
    return null;
  }

  PhaseComparison compare(PmcsPhase phase, Iterable<PmcsFault> currentFaults) {
    final previous = previousFor(phase);
    if (previous == null) return PhaseComparison(phase, null, const []);
    final previousFaultsByItemId = {
      for (final fault in previous.faults)
        if (fault.phase == phase) fault.itemId: fault,
    };
    final current = {
      for (final fault in currentFaults)
        if (fault.phase == phase) fault.itemId: fault,
    };
    final changes = <FaultChange>[];
    for (final fault in current.values) {
      final prior = previousFaultsByItemId[fault.itemId];
      final kind = prior == null
          ? FaultChangeKind.newFault
          : prior.condition != fault.condition ||
                  prior.severity != fault.severity ||
                  (prior.note ?? '').trim() != (fault.note ?? '').trim()
              ? FaultChangeKind.changed
              : FaultChangeKind.recurring;
      changes.add(FaultChange(kind, previous: prior, current: fault));
    }
    for (final fault in previousFaultsByItemId.values) {
      if (!current.containsKey(fault.itemId)) {
        changes.add(
            FaultChange(FaultChangeKind.noLongerReported, previous: fault));
      }
    }
    return PhaseComparison(phase, previous, changes);
  }
}
