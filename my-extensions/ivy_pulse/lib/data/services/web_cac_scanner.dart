import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'package:ivy_pulse/core/constants/app_constants.dart';
import 'package:ivy_pulse/data/services/pdf417_image_decoder.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';

/// Reads a CAC by having the operator photograph it with the device camera.
///
/// A still capture rather than a live preview, for two reasons. The practical
/// one: the host never passes `onPermissionRequest` to the WebView it runs
/// extensions in, so `getUserMedia` is denied outright and a live stream is
/// simply not obtainable today. The better one: `<input type="file"
/// capture="environment">` goes through the WebView's file chooser, which the
/// host's WebView plugin handles natively and hands straight to the Android
/// camera app — full screen, with autofocus and tap-to-focus. That reads a
/// barcode far better than a viewfinder squeezed into the ~370px panel this
/// extension gets.
///
/// The photograph never leaves this object: it is decoded to pixels in memory
/// and dropped, never written to disk by Ivy Pulse and never attached to a
/// report. A JPEG of a Soldier's CAC is not something a maintenance database
/// should ever hold, and photographing a US Government ID card is an offence
/// under 18 U.S.C. § 701.
///
/// That is the whole of what this file can promise, and it is worth being
/// exact about the gap. Capture goes through the OEM camera app, which saves
/// its own copy to DCIM on its own terms, and the host's WebView plugin writes
/// its own temporary file handing the chooser's result across. Neither is
/// reachable from an extension, so the operator is told to clear the gallery
/// rather than told there is nothing to clear.
class WebCacScanner implements CacScannerStrategy {
  final Pdf417ImageDecoder decoder;

  WebCacScanner({this.decoder = const Pdf417ImageDecoder()});

  /// Long edges to try, in order. A CAC's PDF417 is physically small, so a
  /// hard downscale loses the modules — but a full 12MP frame is millions of
  /// pixels of pure-Dart binarisation. The first pass is the one that almost
  /// always hits; the others are there for a card shot small in the frame.
  static const List<int> scanWidths = [1600, 2600, 1000];

  /// How long to wait after the WebView regains focus before calling an
  /// unfired `change` event a cancellation. The file chooser returns focus
  /// before it delivers the file, so this cannot be zero.
  static const Duration cancelGrace = Duration(milliseconds: 1500);

  /// The in-flight capture's completion closure, or null when nothing is in
  /// flight. Held in a field solely so [cancel] has something to call: the
  /// closure itself is local to [_photograph], and without a handle on it
  /// there is no way to end a capture the camera never returns from.
  void Function(web.File?)? _abandon;

  /// Which capture [_abandon] belongs to. A photo the chooser delivers long
  /// after its capture was abandoned still runs that capture's completion
  /// closure, and without this it would clear the handle belonging to the
  /// scan the operator has since started — leaving the live one with no way
  /// out, which is the exact latch all of this exists to prevent.
  int _captureGeneration = 0;

  @override
  Future<bool> isAvailable() async => true;

  /// Gives up on the capture from this side.
  ///
  /// Honestly limited, and the operator is told so: the camera is a separate
  /// full-screen Android activity that this WebView does not own, so nothing
  /// here closes it. What it does is resolve the pending [capture] as
  /// cancelled and drop whatever the chooser delivers afterwards — the late
  /// photo is never rasterised, so one fewer copy of the card exists in this
  /// process than would otherwise. Safe to call when nothing is in flight.
  @override
  Future<void> cancel() async {
    _abandon?.call(null);
  }

  @override
  Future<CacCapture> capture() async {
    final ({web.File? photo, bool timedOut}) shot;
    try {
      shot = await _photograph();
    } catch (e) {
      debugPrint('[IvyPulse] CAC capture failed: $e');
      return const CacCapture.failed(CacRejection.noCamera);
    }
    if (shot.timedOut) {
      return const CacCapture.failed(CacRejection.cameraTimedOut);
    }
    final photo = shot.photo;
    if (photo == null) return const CacCapture.failed(CacRejection.cancelled);

    try {
      return _classify(await _decode(photo));
    } catch (e) {
      debugPrint('[IvyPulse] CAC decode failed: $e');
      return const CacCapture.failed(CacRejection.noCodeFound);
    }
  }

  /// Opens the camera and resolves with the photo, or with nothing and the
  /// reason there is nothing.
  ///
  /// Backing out is the awkward case: a cancelled chooser fires no `change`
  /// event at all. Newer WebViews fire `cancel`, older ones fire nothing, so
  /// the window regaining focus with no file in hand is the backstop, and a
  /// hard timeout is the backstop behind that. Every path completes exactly
  /// once — a future left pending here would latch the submit button off for
  /// the rest of the session, stranding a Soldier with a walked PMCS that can
  /// never be sent.
  Future<({web.File? photo, bool timedOut})> _photograph() {
    final input = web.document.createElement('input') as web.HTMLInputElement
      ..type = 'file'
      ..accept = 'image/*'
      // `environment` asks for the rear camera; a Soldier photographs a
      // card held in front of them, not a selfie.
      ..capture = 'environment';
    input.style.display = 'none';
    web.document.body?.appendChild(input);

    final completer = Completer<({web.File? photo, bool timedOut})>();
    final generation = ++_captureGeneration;
    Timer? cancelTimer;
    Timer? timeoutTimer;
    JSFunction? onFocus;
    var timedOut = false;

    void finish(web.File? file) {
      // Only clear the handle if it is still this capture's.
      if (_captureGeneration == generation) _abandon = null;
      cancelTimer?.cancel();
      timeoutTimer?.cancel();
      if (onFocus != null) {
        web.window.removeEventListener('focus', onFocus);
        onFocus = null;
      }
      if (!completer.isCompleted) {
        completer.complete((photo: file, timedOut: timedOut));
      }
      input.remove();
    }

    _abandon = finish;

    input.onchange = (web.Event _) {
      final files = input.files;
      finish(files != null && files.length > 0 ? files.item(0) : null);
    }.toJS;

    input.oncancel = ((web.Event _) => finish(null)).toJS;

    onFocus = ((web.Event _) {
      // Disarm the previous grace period before arming a new one. Without
      // this, cancellation is judged from the FIRST focus event ever seen
      // rather than the last: a runtime permission dialog bounces focus, the
      // grace expires while the Soldier is still lining the card up, the scan
      // reports itself cancelled, and the real photo is then silently thrown
      // away when `change` finally fires.
      cancelTimer?.cancel();
      cancelTimer = Timer(cancelGrace, () => finish(null));
    }).toJS;
    web.window.addEventListener('focus', onFocus);

    // The camera can crash, be killed for memory, or sit behind a dialog the
    // operator walks away from, and none of those fire an event back into the
    // WebView. Flagged rather than folded into the cancelled path, because
    // "the camera did not come back" and "you backed out" ask the operator
    // for different things.
    timeoutTimer = Timer(AppConstants.cacCaptureTimeout, () {
      timedOut = true;
      finish(null);
    });

    input.click();
    return completer.future;
  }

  /// Turns a decode outcome into the answer the operator sees.
  ///
  /// Deliberately thin. Nothing here knows what a CAC barcode looks like —
  /// even the Code 39 off the back is handed up as an ordinary read so that
  /// `ParseCacBarcode` decides what the string is, where the DMDC format
  /// rules stay testable without a camera.
  CacCapture _classify(Pdf417Read read) {
    final text = read.text;
    if (text != null) return CacCapture.read(text);

    final code39 = read.code39Text;
    if (code39 != null) return CacCapture.read(code39);

    if (!read.located) return const CacCapture.failed(CacRejection.noCodeFound);

    final modulePx = read.modulePx;
    if (modulePx != null &&
        modulePx < Pdf417ImageDecoder.minDecodableModulePx) {
      return const CacCapture.failed(CacRejection.cardTooSmall);
    }
    return const CacCapture.failed(CacRejection.codeUnreadable);
  }

  /// JPEG in, decode outcome out. The browser owns the image codec, so nothing
  /// here has to decode JPEG itself.
  Future<Pdf417Read> _decode(web.File photo) async {
    // One JPEG decode for every pass. This call used to sit inside the loop,
    // which put the browser through a 12MP JPEG three times per scan for a
    // bitmap that is immutable and reusable — the single most expensive thing
    // this file did, and it bought nothing.
    //
    // `from-image` applies the EXIF rotation a phone writes on a portrait
    // shot, so the card arrives the way the operator saw it.
    final bitmap = await web.window
        .createImageBitmap(
          photo,
          web.ImageBitmapOptions(imageOrientation: 'from-image'),
        )
        .toDart;

    try {
      var located = false;
      double? widestModulePx;

      for (final width in scanWidths) {
        final frame = _rasterise(bitmap, targetWidth: width);
        if (frame == null) continue;

        final read = decoder.decodeRgba(
          frame.pixels,
          width: frame.width,
          height: frame.height,
        );
        // A Code 39 hit is as final as a PDF417 one: it means the back of the
        // card is facing the camera, and the front's symbol cannot be in this
        // frame at any scale.
        if (read.text != null || read.code39Text != null) return read;

        located |= read.located;
        // Keep the most generous measurement, not the last one. Module width
        // scales with the pass, so judging "too small" off a downscaled pass
        // when a larger one measured the same symbol wider would tell an
        // operator who framed the card correctly to move closer.
        final modulePx = read.modulePx;
        if (modulePx != null &&
            (widestModulePx == null || modulePx > widestModulePx)) {
          widestModulePx = modulePx;
        }
      }

      return Pdf417Read.miss(located: located, modulePx: widestModulePx);
    } finally {
      // One bitmap, freed once. An EUD does not have the headroom to hold a
      // 12MP frame a moment longer than it must.
      bitmap.close();
    }
  }

  /// Draws [bitmap] onto a canvas scaled so its long edge is [targetWidth],
  /// and reads the pixels back. Never scales up — enlarging a small photo
  /// invents no modules and only costs time.
  _Frame? _rasterise(web.ImageBitmap bitmap, {required int targetWidth}) {
    final longEdge =
        bitmap.width > bitmap.height ? bitmap.width : bitmap.height;
    if (longEdge == 0) return null;

    final scale = targetWidth >= longEdge ? 1.0 : targetWidth / longEdge;
    final width = (bitmap.width * scale).round();
    final height = (bitmap.height * scale).round();
    if (width <= 0 || height <= 0) return null;

    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = width
      ..height = height;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (context == null) return null;

    context.drawImage(bitmap, 0, 0, width.toDouble(), height.toDouble());
    final data = context.getImageData(0, 0, width, height);

    // A view, not a copy: the frame is several megabytes and is thrown away
    // as soon as it is decoded. The offset is honoured rather than assumed —
    // a clamped array need not start at the head of its buffer.
    final clamped = data.data.toDart;
    return _Frame(
      pixels: Uint8List.view(
        clamped.buffer,
        clamped.offsetInBytes,
        clamped.lengthInBytes,
      ),
      width: width,
      height: height,
    );
  }
}

class _Frame {
  final Uint8List pixels;
  final int width;
  final int height;

  const _Frame({
    required this.pixels,
    required this.width,
    required this.height,
  });
}

CacScannerStrategy createCacScanner() => WebCacScanner();
