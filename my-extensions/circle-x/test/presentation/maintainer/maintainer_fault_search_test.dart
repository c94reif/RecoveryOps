import 'package:flutter_test/flutter_test.dart';
import 'package:circle_x/domain/entities/pmcs_phase.dart';
import 'package:circle_x/presentation/maintainer/maintainer_fault_search.dart';
import '../../support/fakes.dart';

void main() {
  test(
      'search matches fault details and both note types, preserving original indexes',
      () {
    final report = buildReport(faults: [
      buildFault(itemId: 'B-ENG-01', note: 'Oil pooling below engine'),
      buildFault(
          itemId: 'B-BRK-02',
          category: 'BRAKES',
          subcategory: 'Brake lines',
          condition: 'Wet hydraulic hose'),
      buildFault(itemId: 'B-ENG-01', phase: PmcsPhase.during),
    ]);
    const notes = ['Lower seam leak confirmed', 'Pressure checked', ''];
    expect(matchingFaultIndexes(report, notes, ''), [0, 1, 2]);
    expect(matchingFaultIndexes(report, notes, '  BRAKES   hydraulic  '), [1]);
    expect(matchingFaultIndexes(report, notes, 'brake lines'), [1]);
    expect(matchingFaultIndexes(report, notes, 'B-ENG-01 during'), [2]);
    expect(matchingFaultIndexes(report, notes, 'pooling'), [0]);
    expect(matchingFaultIndexes(report, notes, 'engine lower'), [0]);
    expect(matchingFaultIndexes(report, notes, 'pressure'), [1]);
    expect(matchingFaultIndexes(report, notes, 'dipstick'), [0, 1, 2]);
    expect(matchingFaultIndexes(report, notes, 'missing fault'), isEmpty);
  });
}
