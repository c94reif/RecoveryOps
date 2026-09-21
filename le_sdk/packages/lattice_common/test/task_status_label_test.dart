import 'package:flutter_test/flutter_test.dart';
import 'package:lattice_common/lattice_common.dart';

void main() {
  group('statusLabelFromStatus', () {
    test('DONE_NOT_OK + cancelled code → "Cancelled"', () {
      expect(
        TaskData.statusLabelFromStatus(10, TaskErrorCode.cancelled),
        'Cancelled',
      );
    });

    test('DONE_NOT_OK + rejected code → "Cannot Comply" (regression)', () {
      expect(
        TaskData.statusLabelFromStatus(10, TaskErrorCode.rejected),
        'Cannot Comply',
      );
    });

    test('DONE_NOT_OK + no code → "Failed" (regression)', () {
      expect(TaskData.statusLabelFromStatus(10, null), 'Failed');
    });

    test('DONE_OK → "Completed" (regression)', () {
      expect(TaskData.statusLabelFromStatus(9, null), 'Completed');
    });
  });
}
