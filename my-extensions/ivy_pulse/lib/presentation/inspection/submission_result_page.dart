import 'package:flutter/material.dart';

import 'package:ivy_pulse/core/di/injection.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/transport_kind.dart';
import 'package:ivy_pulse/domain/services/delivery_coordinator.dart';
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
        final lattice = model.deliveryStatus(TransportKind.lattice);
        final mesh = model.deliveryStatus(TransportKind.mesh);
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
                  style: TextStyle(color: circleXAmber)),
            ...[
              deliveryRow('Lattice', lattice),
              deliveryRow('Mesh', mesh),
              if (lattice == DeliveryStatus.queued ||
                  mesh == DeliveryStatus.queued)
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

  Widget deliveryRow(String label, DeliveryStatus? status) {
    final text = switch (status) {
      null || DeliveryStatus.sending => 'Sending…',
      DeliveryStatus.sent => 'Sent',
      DeliveryStatus.queued => 'Queued',
      DeliveryStatus.failed => 'Delivery unavailable',
      DeliveryStatus.discarded => 'Not sent',
    };
    final color = status == DeliveryStatus.sent
        ? serviceableGreen
        : status == null || status == DeliveryStatus.sending
            ? textSecondary
            : circleXAmber;
    final icon = switch (status) {
      null || DeliveryStatus.sending => Icons.sync,
      DeliveryStatus.sent => Icons.check_circle_outline,
      DeliveryStatus.queued => Icons.schedule,
      _ => Icons.error_outline,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
            child: Text('$label · $text',
                style: TextStyle(color: color, fontSize: 15))),
      ]),
    );
  }
}
