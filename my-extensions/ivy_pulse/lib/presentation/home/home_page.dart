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

  Widget buildTab(int i, IconData icon, String label, int unreadCount) {
    final selected = homeViewModel.pageIndex == i;
    final color = tabColor(i);
    final iconWidget = Icon(icon, size: 20, color: color);
    void select() {
      FocusManager.instance.primaryFocus?.unfocus();
      homeViewModel.selectTab(i);
    }

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        value: i == 1 && unreadCount > 0 ? '$unreadCount unread' : null,
        onTap: select,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? greenGlow : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: InkWell(
              onTap: select,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: minTouchTarget),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (i == 1 && unreadCount > 0)
                        Badge.count(count: unreadCount, child: iconWidget)
                      else
                        iconWidget,
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
                Material(
                  color: bgDark,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: ValueListenableBuilder<int>(
                        valueListenable: getIt<ReportsViewModel>().unreadCount,
                        builder: (_, count, __) => Row(
                          children: [
                            for (final (i, tab) in [
                              (Icons.checklist_rtl, 'PMCS'),
                              (Icons.assignment_late_outlined, 'Reports'),
                              (Icons.person, 'Profile'),
                            ].indexed)
                              buildTab(i, tab.$1, tab.$2, count),
                          ],
                        ),
                      ),
                    ),
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
