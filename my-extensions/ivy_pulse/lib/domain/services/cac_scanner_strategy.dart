import 'package:ivy_pulse/domain/entities/cac_scan.dart';

/// Reads the PDF417 on the front of a CAC with the device camera.
///
/// A CAC carries two barcodes, on opposite faces, and only one of them can
/// sign a 5988-E. Stated in full here because the wrong half of it is the
/// mistake every layer above this one has to guard against:
///
/// - **Front**, printed *portrait* (CR80, 1:1.587). Photo upper left, gold ICC
///   chip lower centre, and the **PDF417** in the lower-left corner
///   immediately left of that chip — about 12.5 x 24.7 mm, some 6% of the
///   face. 89 characters (88 on a legacy version-`1` card): name, rank,
///   branch, personnel category, DoD ID, expiry. This is the one this port
///   reads.
/// - **Back**, printed *landscape* — so the two faces' "up" directions are 90
///   degrees apart. A horizontal **Code 39** strip about 70 x 9.3 mm runs
///   along the long edge. 18 characters, and no name, no rank, no dates. It
///   can never sign anything; its only use is telling an operator they
///   photographed the wrong face.
///
/// Never describe either one to an operator as "the front". At an installation
/// gate a Soldier is trained to present the *back* so AIE/DBIDS can read that
/// Code 39 strip, and every state driving licence in their wallet carries its
/// PDF417 on the back as well — so "front" is the one word guaranteed to send
/// them the wrong way. Name landmarks instead: the photo, the gold chip, the
/// tall barcode beside it.
///
/// Only the capture and the decode live behind this port. Turning the barcode
/// into a Soldier is `ParseCacBarcode`'s job, so the rules the DMDC spec lays
/// down stay testable without a camera.
abstract class CacScannerStrategy {
  /// False when nothing on this platform can reach a camera, so the operator
  /// finds out before they have walked a whole PMCS they cannot sign.
  Future<bool> isAvailable();

  /// Opens the camera and returns the decoded barcode text, or why it could
  /// not.
  ///
  /// The frame does not leave this call: it is decoded in memory and dropped,
  /// never written to disk by this app and never attached to a report. That is
  /// the whole of what an extension can promise. Photographing a US Government
  /// ID card is an offence under 18 U.S.C. § 701, and two copies are outside
  /// this code's reach — the OEM camera app's own DCIM copy, and whatever
  /// temporary file the host's WebView plugin writes handing the file chooser
  /// its result. Neither is deletable from here, which is why the operator is
  /// told about the gallery rather than reassured.
  Future<CacCapture> capture();

  /// Abandons a capture that is already in flight.
  ///
  /// Honestly limited, and the limit must be said out loud to the operator:
  /// the camera is a separate full-screen activity the WebView does not own,
  /// so nothing here can close it. What this does is give up on this side —
  /// the pending [capture] resolves as cancelled, and a photo that lands
  /// afterwards is dropped without ever being rasterised, so one fewer copy
  /// of the card exists in this process than would otherwise.
  ///
  /// It exists because the alternative is worse than useless: with no way out
  /// of a capture that never returns, the operator is left holding a walked
  /// PMCS they cannot submit and cannot retry. Safe to call when nothing is
  /// in flight.
  Future<void> cancel();
}
