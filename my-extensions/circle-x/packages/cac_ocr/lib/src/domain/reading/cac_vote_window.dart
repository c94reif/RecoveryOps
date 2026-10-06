class CacVoteWindow<T extends Object> {
  final int size;
  final int needed;
  final _votes = <T?>[];

  CacVoteWindow({required this.size, required this.needed})
      : assert(needed <= size);

  bool add(T? reading) {
    _votes.add(reading);
    if (_votes.length > size) _votes.removeAt(0);
    return reading != null && !contested && backing >= needed;
  }

  int get backing {
    final last = _votes.lastOrNull;
    return last == null ? 0 : _votes.where((vote) => vote == last).length;
  }

  bool get contested {
    final last = _votes.lastOrNull;
    return last != null && _votes.any((vote) => vote != null && vote != last);
  }

  void clear() => _votes.clear();
}
