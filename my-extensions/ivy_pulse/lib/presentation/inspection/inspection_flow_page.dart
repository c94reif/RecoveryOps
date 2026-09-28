import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/di/service_locator.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_page.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';
import 'package:ivy_pulse/presentation/inspection/phase_select_page.dart';
import 'package:ivy_pulse/presentation/inspection/setup_page.dart';
import 'package:ivy_pulse/presentation/inspection/summary_page.dart';
import 'package:ivy_pulse/presentation/inspection/submission_result_page.dart';

class InspectionFlowPage extends StatefulWidget {
  const InspectionFlowPage({super.key});

  @override
  State<InspectionFlowPage> createState() => InspectionFlowPageState();
}

class InspectionFlowPageState extends State<InspectionFlowPage> {
  late final InspectionViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = getIt<InspectionViewModel>();
    viewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => switch (viewModel.stage) {
        InspectionStage.setup => const SetupPage(),
        InspectionStage.phaseSelect => const PhaseSelectPage(),
        InspectionStage.inspecting => const InspectionPage(),
        InspectionStage.summary => const SummaryPage(),
        InspectionStage.submitted => const SubmissionResultPage(),
      },
    );
  }
}
