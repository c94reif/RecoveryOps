import 'package:cac_ocr/src/domain/cac_name.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';

sealed class CacCapture {
  const CacCapture();

  const factory CacCapture.barcode(String raw) = CacBarcodeCapture;

  const factory CacCapture.fields(String dodId,
      {CacName? name, String rank, DateTime? expiresOn}) = CacFieldsCapture;

  const factory CacCapture.failed(CacRejection rejection) = CacFailedCapture;

  CacRejection? get rejection => null;
}

final class CacBarcodeCapture extends CacCapture {
  final String raw;

  const CacBarcodeCapture(this.raw);
}

final class CacFieldsCapture extends CacCapture {
  final String dodId;
  final CacName? name;
  final String rank;
  final DateTime? expiresOn;

  const CacFieldsCapture(this.dodId,
      {this.name, this.rank = '', this.expiresOn});
}

final class CacFailedCapture extends CacCapture {
  @override
  final CacRejection rejection;

  const CacFailedCapture(this.rejection);
}
