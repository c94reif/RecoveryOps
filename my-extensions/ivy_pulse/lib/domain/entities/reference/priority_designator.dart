class PriorityDesignator {
  final String code;
  final String label;

  const PriorityDesignator({required this.code, required this.label});

  static const routine = PriorityDesignator(code: '09', label: 'Routine');
}
