abstract interface class TransactionRunner {
  Future<T> run<T>(Future<T> Function() action);
}
