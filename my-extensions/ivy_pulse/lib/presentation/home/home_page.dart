import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_snack_bar.dart';
import 'package:ivy_pulse/presentation/home/home_view_model.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_flow_page.dart';
import 'package:ivy_pulse/presentation/profile/profile_page.dart';
import 'package:ivy_pulse/presentation/reports/reports_page.dart';
import 'package:ivy_pulse/presentation/reports/reports_view_model.dart';

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
  }

  Color tabColor(int i) =>
      homeViewModel.pageIndex == i ? masterChiefGreen : textSecondary;

  Widget tabIcon(int i, IconData icon) {
    final color = tabColor(i);
    final iconWidget = Icon(icon, size: 18, color: color);
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
                    children: const [
                      InspectionFlowPage(),
                      ReportsPage(),
                      ProfilePage(),
                    ],
                  ),
                ),
                Container(
                  color: bgDark,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      for (final (i, tab) in [
                        (Icons.checklist_rtl, 'PMCS'),
                        (Icons.assignment_late_outlined, 'Reports'),
                        (Icons.person, 'Profile'),
                      ].indexed)
                        Expanded(
                          // Gloved thumbs miss small targets, and a mistap here
                          // can drop an operator out of an open inspection.
                          child: SizedBox(
                            height: minTouchTarget,
                            child: GestureDetector(
                              onTap: () {
                                homeViewModel.selectTab(i);
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
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
