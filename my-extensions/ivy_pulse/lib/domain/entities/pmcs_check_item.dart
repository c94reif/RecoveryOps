class PmcsCheckItem {
  final String id;

  final String item;

  final String check;

  final List<String> faults;

  const PmcsCheckItem({
    required this.id,
    required this.item,
    required this.check,
    required this.faults,
  });

  String get serviceableLabel => faults.isEmpty ? 'Serviceable' : faults.first;

  String labelAt(int faultIndex) {
    if (faultIndex < 0 || faultIndex >= faults.length) return '';
    return faults[faultIndex];
  }
}
