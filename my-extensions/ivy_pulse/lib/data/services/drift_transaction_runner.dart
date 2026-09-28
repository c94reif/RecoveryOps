import 'package:ivy_pulse/data/datasources/local/database.dart';
import 'package:ivy_pulse/domain/services/transaction_runner.dart';

class DriftTransactionRunner implements TransactionRunner {
  final AppDatabase database;
  const DriftTransactionRunner(this.database);

  @override
  Future<T> run<T>(Future<T> Function() action) => database.transaction(action);
}
