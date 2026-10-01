abstract interface class UserNotificationSink {
  void enqueue(String message, {bool isError = false, bool persistent = false});
}

class SilentNotificationSink implements UserNotificationSink {
  const SilentNotificationSink();

  @override
  void enqueue(String message,
      {bool isError = false, bool persistent = false}) {}
}
