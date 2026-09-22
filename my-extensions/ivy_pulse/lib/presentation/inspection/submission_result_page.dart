import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/presentation/common/widgets/custom_button.dart';
import 'package:ivy_pulse/presentation/home/home_view_model.dart';
import 'package:ivy_pulse/presentation/inspection/inspection_view_model.dart';
import 'package:ivy_pulse/presentation/reports/reports_view_model.dart';

class SubmissionResultPage extends StatelessWidget {
  const SubmissionResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = getIt<InspectionViewModel>();
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final report = model.submittedReport;
        if (report == null) return const SizedBox.shrink();
        final outcome = model.submissionDelivery;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Icon(Icons.check_circle_outline,
                color: serviceableGreen, size: 40),
            const SizedBox(height: 12),
            const Text('PMCS saved',
                style: TextStyle(
                    color: textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(report.summary,
                style: const TextStyle(color: textPrimary, fontSize: 18)),
            Text('UIC ${report.uic}',
                style: const TextStyle(color: textSecondary)),
            const SizedBox(height: 12),
            const Text('Your report is saved on this device.'),
            if (!report.isSignatureVerified) ...[
              const SizedBox(height: 8),
              const Text('Signed without CAC verification',
                  style: TextStyle(color: circleXAmber)),
            ],
            const SizedBox(height: 20),
            if (model.submissionDeliveryFailed)
              const Text(
                  'Delivery status unavailable. Your saved report is available in Reports.',
                  style: TextStyle(color: circleXAmber))
            else ...[
              deliveryRow('Lattice', outcome?.latticeOk),
              deliveryRow('Mesh', outcome?.meshOk),
              if (outcome != null && !outcome.allSucceeded)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                      'Queued delivery will retry when the connection returns.'),
                ),
            ],
            const SizedBox(height: 24),
            CustomButton(
              text: 'View report',
              icon: Icons.assignment_outlined,
              onPressed: getIt.isRegistered<ReportsViewModel>() &&
                      getIt.isRegistered<HomeViewModel>()
                  ? () {
                      getIt<ReportsViewModel>().reportToOpen.value = report;
                      getIt<HomeViewModel>().selectTab(1);
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            TextButton(
                onPressed: model.resetToSetup,
                child: const Text('Start another PMCS')),
          ],
        );
      },
    );
  }

  Widget deliveryRow(String label, bool? sent) {
    final text = sent == null
        ? 'Sending…'
        : sent
            ? 'Sent'
            : 'Queued';
    final color = sent == null
        ? textSecondary
        : sent
            ? serviceableGreen
            : circleXAmber;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(
            sent == null
                ? Icons.sync
                : sent
                    ? Icons.check_circle_outline
                    : Icons.schedule,
            color: color,
            size: 22),
        const SizedBox(width: 10),
        Expanded(
            child: Text('$label · $text',
                style: TextStyle(color: color, fontSize: 15))),
      ]),
    );
  }
}
