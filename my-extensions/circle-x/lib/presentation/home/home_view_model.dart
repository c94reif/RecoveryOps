import 'package:flutter/material.dart';

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
