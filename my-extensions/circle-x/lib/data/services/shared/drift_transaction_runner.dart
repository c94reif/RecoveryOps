import 'package:circle_x/data/datasources/local/database.dart';
import 'package:circle_x/domain/shared/services/transaction_runner.dart';

class DriftTransactionRunner implements TransactionRunner {
  final AppDatabase database;
  const DriftTransactionRunner(this.database);

  @override
  Future<T> run<T>(Future<T> Function() action) => database.transaction(action);
}
