class PublishResult {
  final bool latticeOk;
  final bool meshOk;

  const PublishResult({
    required this.latticeOk,
    required this.meshOk,
  });

  bool get allSucceeded => latticeOk && meshOk;
  bool get allFailed => !latticeOk && !meshOk;
}
