/// A single numbered PMCS check transcribed from the vehicle's TM.
///
/// [faults] is ordered by escalating condition: index 0 is always the
/// serviceable/no-fault option, and severity rises with the index. The
/// fault classifier maps (id, index) to a [FaultSeverity].
class PmcsCheckItem {
  /// TM item number, e.g. `B-ENG-01` or `JLTV-CRIT-B02`.
  final String id;

  /// The component being inspected, e.g. `Engine Oil Level`.
  final String item;

  /// The TM instruction telling the operator what to look for.
  final String check;

  /// Selectable conditions, serviceable first.
  final List<String> faults;

  const PmcsCheckItem({
    required this.id,
    required this.item,
    required this.check,
    required this.faults,
  });

  /// The option an operator picks when nothing is wrong.
  String get serviceableLabel => faults.isEmpty ? 'Serviceable' : faults.first;

  String labelAt(int faultIndex) {
    if (faultIndex < 0 || faultIndex >= faults.length) return '';
    return faults[faultIndex];
  }
}
