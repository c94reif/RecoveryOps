import 'package:flutter/material.dart';

/// Owns which shell tab is showing. Tab state is deliberately separate from
/// the inspection state so a Soldier can check Reports mid walk-around and
/// come back to the same TM check.
class HomeViewModel extends ChangeNotifier {
  int pageIndex = 0;

  static const List<String> pageTitles = [
    'PMCS',
    'Reports',
    'Profile',
  ];

  void selectTab(int index) {
    pageIndex = index;
    notifyListeners();
  }
}
