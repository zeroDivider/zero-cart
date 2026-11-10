/// Callable that returns the current instant (UTC in production).
typedef Clock = DateTime Function();

/// Default clock: wall time in UTC.
DateTime systemClock() => DateTime.now().toUtc();
