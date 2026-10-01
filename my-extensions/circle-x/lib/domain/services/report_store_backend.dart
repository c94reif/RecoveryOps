/// Selects remote persistence only. Local storage and peer delivery are separate.
enum ReportStoreBackend {
  meshItemStore,
  entities;

  static ReportStoreBackend fromEnvironment() =>
      parse(const String.fromEnvironment('REPORT_STORE',
          defaultValue: 'meshItemStore'));

  static ReportStoreBackend parse(String value) => switch (value) {
        'meshItemStore' => meshItemStore,
        'entities' => entities,
        _ => throw ArgumentError.value(
            value, 'REPORT_STORE', 'expected meshItemStore or entities'),
      };
}
