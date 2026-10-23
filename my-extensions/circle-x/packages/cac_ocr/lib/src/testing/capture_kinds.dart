import 'package:cac_ocr/src/domain/cac_capture.dart';

extension CacCaptureKinds on CacCapture {
  CacFieldsCapture get asFields => this as CacFieldsCapture;
  CacBarcodeCapture get asBarcode => this as CacBarcodeCapture;
}
