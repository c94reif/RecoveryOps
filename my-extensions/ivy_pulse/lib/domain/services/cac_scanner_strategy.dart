import 'package:ivy_pulse/domain/entities/cac_scan.dart';

/// Reads the DoD ID number off the **back** of a CAC with the device camera.
///
/// A CAC has two faces, and the one this port wants is the one a Soldier is
/// already trained to present — at an installation gate the *back* goes on
/// the AIE/DBIDS reader. Stated in full because the two faces are printed
/// ninety degrees apart and confusing them is the mistake every layer above
/// this one has to guard against:
///
/// - **Back**, printed *landscape*. A wide **Code 39** strip runs along the
///   long edge, and the **DoD ID Number** is printed in plain digits above
///   it, beside the DoD Benefits Number and the date of birth. This is the
///   face this port reads: on Android by OCR of the printed number from a
///   live preview, on the web build by decoding the strip, which encodes
///   the same number.
/// - **Front**, printed *portrait*. Photo, name, rank, gold chip, and a tall
///   PDF417 beside the chip carrying the full record. The web build still
///   decodes it if it is what the camera is shown, but nothing asks for it.
///
/// What comes off the back is a number and nothing else — no name, no rank —
/// so a signature made this way names the Soldier by DoD ID. Name landmarks
/// to the operator, not faces: the wide strip, the DoD ID number above it.
///
/// Only the capture and the read live behind this port. Turning what was
/// read into a Soldier is `ParseDodId`'s job (and `ParseCacBarcode`'s for a
/// barcode record), so the rules stay testable without a camera. A capture
/// hands back either the ten-digit number or the raw barcode text; the
/// verify step tells them apart by shape.
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
