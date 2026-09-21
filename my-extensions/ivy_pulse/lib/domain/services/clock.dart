/// Injectable time source. Every timestamp in the domain flows through this so
/// use cases stay deterministic under test.
abstract class Clock {
  DateTime nowUtc();
}

/// Wall-clock implementation used in production.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// Fixed clock for tests.
class FixedClock implements Clock {
  final DateTime instant;

  const FixedClock(this.instant);

  @override
  DateTime nowUtc() => instant.toUtc();
}
