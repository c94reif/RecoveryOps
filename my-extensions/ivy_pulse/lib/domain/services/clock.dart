abstract class Clock {
  DateTime nowUtc();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

class FixedClock implements Clock {
  final DateTime instant;

  const FixedClock(this.instant);

  @override
  DateTime nowUtc() => instant.toUtc();
}
