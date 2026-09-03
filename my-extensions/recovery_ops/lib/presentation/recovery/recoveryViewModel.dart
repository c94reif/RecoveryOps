import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:uuid/uuid.dart';
import 'package:recovery_ops/domain/entities/publishResult.dart';
import 'package:recovery_ops/domain/entities/recoveryRequest.dart';
import 'package:recovery_ops/domain/entities/transportKind.dart';
import 'package:recovery_ops/domain/services/speechRecognitionStrategy.dart';
import 'package:recovery_ops/domain/services/transcriptParserStrategy.dart';
import 'package:recovery_ops/domain/usecases/recovery/publishRecoveryRequest.dart';
import 'package:recovery_ops/domain/usecases/reporting/submitOutgoingReport.dart';
import 'package:recovery_ops/presentation/common/widgets/customSnackBar.dart';
import 'package:recovery_ops/presentation/reports/reportsViewModel.dart';

class RecoveryViewModel extends ChangeNotifier {
  final SpeechRecognitionStrategy speechStrategy;
  final TranscriptParserStrategy parserStrategy;
  final SubmitOutgoingReport submitOutgoingReport;
  final sdk.MapService mapService;
  final PublishRecoveryRequest publishRecoveryRequest;
  final ReportsViewModel reportsViewModel;
  final SnackBarService snackBarService;

  RecoveryViewModel(
    this.speechStrategy,
    this.parserStrategy, {
    required this.submitOutgoingReport,
    required this.mapService,
    required this.publishRecoveryRequest,
    required this.reportsViewModel,
    SnackBarService? snackBarService,
  }) : snackBarService = snackBarService ?? SnackBarService.instance;

  RecoveryType selectedType = RecoveryType.towBar;
  bool isListening = false;
  bool isParsing = false;
  String? bumperResult;
  String? issueResult;
  RecoveryType? typeResult;
  String? listeningField;

  void selectType(RecoveryType type) {
    selectedType = type;
    notifyListeners();
  }

  bool validate(String bumperNumber, String issue) {
    if (bumperNumber.trim().isEmpty || issue.trim().isEmpty) {
      snackBarService.enqueue(
        'Bumper number and issue are required',
        isError: true,
      );
      return false;
    }
    return true;
  }

  void onSubmitSuccess() {
    selectedType = RecoveryType.towBar;
    notifyListeners();
  }

  Future<void> addOutgoingReport({
    required String entityId,
    required String bumperNumber,
    required String issue,
    required String recoveryType,
    required double latitude,
    required double longitude,
  }) async {
    debugPrint('[RecoveryOps] addOutgoingReport — persisting outgoing report '
        '(entityId=$entityId, bumper="$bumperNumber")');
    final report = await submitOutgoingReport(
      entityId: entityId,
      bumperNumber: bumperNumber,
      issue: issue,
      recoveryType: recoveryType,
      latitude: latitude,
      longitude: longitude,
    );
    reportsViewModel.reports.insert(0, report);
    reportsViewModel.notifyListeners();
    debugPrint('[RecoveryOps] addOutgoingReport — stored & inserted into '
        'reports list (total=${reportsViewModel.reports.length})');
  }

  Future<void> submitRecoveryRequest({
    required String bumperNumber,
    required String issue,
    required RecoveryType type,
    required LatLng position,
  }) async {
    final entityId = const Uuid().v4();
    final label = type == RecoveryType.towBar ? 'Tow Bar' : 'Wrecker';
    debugPrint('[RecoveryOps] submitRecoveryRequest — entityId=$entityId, '
        'bumper="$bumperNumber", issue="$issue", type=$label, '
        'pos=(${position.latitude}, ${position.longitude})');

    await addOutgoingReport(
      entityId: entityId,
      bumperNumber: bumperNumber,
      issue: issue,
      recoveryType: label,
      latitude: position.latitude,
      longitude: position.longitude,
    );

    mapService.flyTo(
      sdk.LatLng(position.latitude, position.longitude),
      zoom: 15,
    );
    debugPrint('[RecoveryOps] submitRecoveryRequest — dispatching publish '
        '(lattice + mesh) for entityId=$entityId');

    publishRecoveryRequest
        .call(
      entityId: entityId,
      bumperNumber: bumperNumber,
      issue: issue,
      type: type,
      position: position,
    )
        .then(_announceLegOutcomes)
        .catchError((e) {
      debugPrint('[RecoveryOps] Publish error: $e');
      snackBarService.enqueue('Publish error: $e', isError: true);
    });
  }

  void _announceLegOutcomes(PublishResult outcome) {
    if (outcome.latticeOk) {
      snackBarService.enqueue(
        '${TransportKind.lattice.displayName}: passed',
        isError: false,
      );
    }
    if (outcome.meshOk) {
      snackBarService.enqueue(
        '${TransportKind.mesh.displayName}: passed',
        isError: false,
      );
    }
  }

  Future<void> parseTranscript(String text) async {
    final parsed = await parserStrategy.parse(text);

    bumperResult = parsed.bumperNumber;
    issueResult = parsed.issue;
    typeResult = parsed.recoveryType;

    if (typeResult != null) {
      selectedType = typeResult!;
    }

    notifyListeners();
  }

  Future<void> startListening() async {
    isListening = true;
    notifyListeners();

    await speechStrategy.startListening(
      onResult: (text) async {
        isListening = false;
        isParsing = true;
        notifyListeners();
        await parseTranscript(text);
        isParsing = false;
        notifyListeners();
      },
    );
  }

  Future<void> stopListening() async {
    await speechStrategy.stopListening();
    isListening = false;
    notifyListeners();
  }

  Future<void> toggleListening() async {
    if (isListening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  Future<void> startFieldListening(
    String field,
    void Function(String) onResult,
  ) async {
    listeningField = field;
    isListening = true;
    notifyListeners();

    await speechStrategy.startListening(
      onResult: (text) {
        isListening = false;
        listeningField = null;
        onResult(text);
        notifyListeners();
      },
    );
  }

  Future<void> stopFieldListening() async {
    await speechStrategy.stopListening();
    isListening = false;
    listeningField = null;
    notifyListeners();
  }

  Future<void> toggleFieldListening(
    String field,
    void Function(String) onResult,
  ) async {
    if (isListening && listeningField == field) {
      await stopFieldListening();
    } else {
      if (isListening) await stopFieldListening();
      await startFieldListening(field, onResult);
    }
  }
}
