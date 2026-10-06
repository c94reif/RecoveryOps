import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/domain/reading/cac_vote_window.dart';

void main() {
  CacVoteWindow<String> window() => CacVoteWindow(size: 5, needed: 3);

  test('agrees once enough readings match', () {
    final votes = window();
    expect(votes.add('A'), isFalse);
    expect(votes.add('A'), isFalse);
    expect(votes.add('A'), isTrue);
    expect(votes.backing, 3);
  });

  test('a reading of nothing neither counts nor restarts the count', () {
    final votes = window();
    for (final reading in ['A', null, 'A', null]) {
      expect(votes.add(reading), isFalse);
    }
    expect(votes.backing, 0, reason: 'the latest reading was nothing');
    expect(votes.add('A'), isTrue);
  });

  test('another reading holds the count back until it leaves the window', () {
    final votes = window()
      ..add('A')
      ..add('B');
    for (var frame = 1; frame < 5; frame++) {
      expect(votes.add('A'), isFalse, reason: 'B is still in the window');
      expect(votes.contested, isTrue);
    }
    expect(votes.add('A'), isTrue);
    expect(votes.contested, isFalse);
  });

  test('clearing forgets every reading', () {
    final votes = window()
      ..add('A')
      ..add('A')
      ..clear();
    expect(votes.backing, 0);
    expect(votes.add('A'), isFalse);
  });
}
