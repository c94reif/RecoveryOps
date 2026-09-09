import 'package:flutter/material.dart';
import 'package:recovery_ops/core/di/injection.dart';
import 'package:recovery_ops/core/theme/app_theme.dart';
import 'package:recovery_ops/presentation/common/widgets/custom_snack_bar.dart';
import 'package:recovery_ops/presentation/home/home_view_model.dart';
import 'package:recovery_ops/presentation/reports/reports_view_model.dart';
import 'package:recovery_ops/presentation/profile/profile_page.dart';
import 'package:recovery_ops/presentation/reports/reports_page.dart';
import 'package:recovery_ops/presentation/navigation/navigation_page.dart';
import 'package:recovery_ops/presentation/recovery/recovery_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late final HomeViewModel homeViewModel;

  @override
  void initState() {
    super.initState();
    homeViewModel = getIt<HomeViewModel>();
    goToCurrentLocation();
  }

  Future<void> goToCurrentLocation() async {
    await homeViewModel.getInitialLocation();
  }

  static const navBlue = Color(0xFF4A90D9);

  Color tabColor(int i) {
    if (homeViewModel.pageIndex != i) return Colors.white60;
    if (i == 2) return navBlue;
    return masterChiefGreen;
  }

  Widget tabIcon(int i, IconData icon) {
    final color = tabColor(i);
    final iconWidget = Icon(icon, size: 16, color: color);
    if (i != 1) return iconWidget;
    return ValueListenableBuilder<int>(
      valueListenable: getIt<ReportsViewModel>().unreadCount,
      builder: (_, count, child) {
        if (count == 0) return child!;
        return Badge(
          label: Text('$count', style: const TextStyle(fontSize: 8)),
          child: child,
        );
      },
      child: iconWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: homeViewModel,
      builder: (context, _) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: CustomSnackBar(
            child: Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: homeViewModel.pageIndex,
                    children: [
                      const RecoveryPage(),
                      const ReportsPage(),
                      const NavigationPage(),
                      const ProfilePage(),
                    ],
                  ),
                ),
                Container(
                  color: const Color(0xFF141619),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      for (final (i, tab) in [
                        (Icons.car_crash, 'Recovery'),
                        (Icons.assignment, 'Reports'),
                        (Icons.navigation, 'Nav'),
                        (Icons.person, 'Profile'),
                      ].indexed)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              homeViewModel.selectTab(i);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                tabIcon(i, tab.$1),
                                const SizedBox(height: 2),
                                Text(
                                  tab.$2,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: tabColor(i),
                                    fontWeight: homeViewModel.pageIndex == i
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
