/// Executes related repository writes as one durable operation.
abstract interface class TransactionRunner {
  Future<T> run<T>(Future<T> Function() action);
}
