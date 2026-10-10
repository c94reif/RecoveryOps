import 'package:circle_x/domain/entities/bumper_number.dart';
import 'package:circle_x/domain/entities/uic.dart';

class ReportSearch {
  final String _query;
  final String _bumperQuery;

  ReportSearch(String search)
      : _query = Uic.normalize(search),
        _bumperQuery = BumperNumber.matchingKey(search);

  bool get isEmpty => _query.isEmpty;

  bool matches({required String bumperNumber, required String uic}) =>
      isEmpty ||
      Uic.normalize(uic).contains(_query) ||
      (_bumperQuery.isEmpty
          ? BumperNumber.normalize(bumperNumber).contains(_query)
          : BumperNumber.matchingKey(bumperNumber).contains(_bumperQuery));
}
