import 'package:flutter/foundation.dart';

const int defaultQuarterTurns = 3;

final ValueNotifier<int> verticalQuarterTurns =
    ValueNotifier<int>(defaultQuarterTurns);

final ValueNotifier<bool> fullScreenOn = ValueNotifier<bool>(false);

final ValueNotifier<bool> fullScreenWanted = ValueNotifier<bool>(true);
