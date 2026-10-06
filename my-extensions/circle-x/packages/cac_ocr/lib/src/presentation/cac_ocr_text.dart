import 'package:flutter/foundation.dart';
import 'package:cac_ocr/src/domain/cac_identity.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';
import 'package:cac_ocr/src/domain/reading/cac_guidance.dart';

@immutable
class CacOcrText {
  final String? promptBothSides;
  final String? promptBackOnly;
  final String? noCamera;
  final String scanButton;
  final List<String> aimGuideBothSides;
  final List<String> aimGuideBackOnly;

  final String scanningFallback;
  final String cancelButton;
  final String? scanningNotice;
  final String frontStep;
  final String backStep;
  final String backOnlyStep;
  final String frontFocusHint;
  final String backFocusHint;
  final String frontGuideLabel;
  final String backGuideLabel;
  final String torchOn;
  final String torchOff;

  final String Function(CacGuidance guidance) guidance;

  final String Function(CacIdentity identity) verifiedTitle;
  final String Function(CacIdentity identity)? verifiedDetail;
  final String Function(CacIdentity identity)? dodIdLine;

  final String Function(CacIdentity identity)? expiresLine;
  final String Function(CacIdentity identity)? expiringSoon;

  final String Function(CacIdentity identity)? expiredAdvisory;
  final String submitButton;
  final String? rescanButton;

  final String Function(CacRejection rejection) rejectionMessage;
  final String expiredTitle;
  final String Function(CacIdentity card)? expiredHolder;
  final String Function(CacIdentity card)? expiredOnLine;
  final String? Function(int attempts, bool bothSides)? retryHint;
  final String scanAgainButton;
  final String unverifiedButton;
  final String? unverifiedNotice;
  final String? galleryAdvisory;

  // The typed fallback.
  final String? typedHeading;
  final String? typedNotice;
  final String lastNameLabel;
  final String firstNameLabel;
  final String dodIdLabel;
  final String? dodIdHint;
  final String typedSubmitButton;

  const CacOcrText({
    this.promptBothSides = 'Scan the front of your CAC for your name, then '
        'flip it when asked to read the DoD ID number on the back.',
    this.promptBackOnly = 'Show the camera the back of your CAC — it reads '
        'your DoD ID number.',
    this.noCamera = 'No camera reachable on this device.',
    this.scanButton = 'SCAN CAC',
    this.aimGuideBothSides = const [
      '1. Show the front — your name below the photo',
      '2. Flip when asked — DoD ID above the wide strip',
      'It reads by itself — no button to press',
    ],
    this.aimGuideBackOnly = const [
      'Turn the card over — the side the gate scans',
      'Fill the box; the DoD ID number sits above the wide strip',
      'It reads by itself — no button to press',
    ],
    this.scanningFallback = 'Reading the card — fill the frame with the back, '
        'the side with the wide barcode strip.',
    this.cancelButton = 'CANCEL SCAN',
    this.scanningNotice = 'Camera frames are discarded after reading. '
        'Cancelling closes the camera.',
    this.frontStep = 'STEP 1 OF 2 — FRONT · NAME',
    this.backStep = 'STEP 2 OF 2 — BACK · DoD ID',
    this.backOnlyStep = 'BACK · DoD ID',
    this.frontFocusHint = 'Tap your name to focus',
    this.backFocusHint = 'Tap the DoD ID number to focus',
    this.frontGuideLabel = 'FRONT — NAME BELOW YOUR PHOTO',
    this.backGuideLabel = 'BACK — DoD ID NUMBER ABOVE THE STRIP',
    this.torchOn = 'Turn on the light',
    this.torchOff = 'Turn off the light',
    this.guidance = _guidance,
    this.verifiedTitle = _verifiedTitle,
    this.verifiedDetail = _verifiedDetail,
    this.dodIdLine = _dodIdLine,
    this.expiresLine = _expiresLine,
    this.expiringSoon = _expiringSoon,
    this.expiredAdvisory = _expiredAdvisory,
    this.submitButton = 'SUBMIT',
    this.rescanButton = 'NOT ME — RESCAN',
    this.rejectionMessage = _rejectionMessage,
    this.expiredTitle = 'CAC EXPIRED',
    this.expiredHolder = _expiredHolder,
    this.expiredOnLine = _expiredOnLine,
    this.retryHint = _retryHint,
    this.scanAgainButton = 'SCAN AGAIN',
    this.unverifiedButton = 'SUBMIT UNVERIFIED',
    this.unverifiedNotice = 'An unverified submission is marked as signed by '
        'nobody this device could check.',
    this.galleryAdvisory = 'This app dropped the photo, but the camera app may '
        'have kept its own copy in the gallery. Delete it there.',
    this.typedHeading = 'OR TYPE IT IN',
    this.typedNotice = 'Goes out marked as typed, not scanned.',
    this.lastNameLabel = 'Last name',
    this.firstNameLabel = 'First name',
    this.dodIdLabel = 'DoD ID',
    this.dodIdHint = '10 digits',
    this.typedSubmitButton = 'SUBMIT WITH TYPED ID',
  });

  static String _guidance(CacGuidance guidance) => guidance.message;

  static String _verifiedTitle(CacIdentity identity) => identity.displayName;

  static String _verifiedDetail(CacIdentity identity) => [
        if (identity.branch.isNotEmpty) identity.branch,
        if (identity.category.isNotEmpty) identity.category,
      ].join(' · ');

  static String _dodIdLine(CacIdentity identity) => 'DoD ID ${identity.dodId}';

  static String _expiresLine(CacIdentity identity) =>
      'Card expires ${formatCardDate(identity.cardExpiresOn!)}';

  static String _expiringSoon(CacIdentity identity) =>
      switch (identity.daysUntilCardExpiry!) {
        < 0 => _expiredAdvisory(identity),
        0 => _expiresWithin('today'),
        1 => _expiresWithin('tomorrow'),
        final days => _expiresWithin('in $days days'),
      };

  static String _expiresWithin(String when) =>
      'This CAC expires $when. Book an ID card appointment before it stops '
      'signing.';

  static String _expiredAdvisory(CacIdentity identity) =>
      'This CAC expired ${formatCardDate(identity.cardExpiresOn!)}. Draw a '
      'current card.';

  static String _rejectionMessage(CacRejection rejection) => rejection.message;

  static String _expiredHolder(CacIdentity card) => card.displayName;

  static String _expiredOnLine(CacIdentity card) =>
      'Expired ${formatCardDate(card.cardExpiresOn!)}';

  static String? _retryHint(int attempts, bool bothSides) => switch (attempts) {
        2 when bothSides => 'Lay the card flat and fill the box with the photo '
            'side first. Keep the name straight across the frame, then flip '
            'the card when asked.',
        2 => 'Lay the card flat and fill the box with the whole back — the '
            'number reads best running straight across the frame.',
        >= 3 => 'Stand so your own shadow falls across the card and tilt it '
            'until the print stops shining.',
        _ => null,
      };
}

String formatCardDate(DateTime date) {
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  final utc = date.toUtc();
  return '${utc.day.toString().padLeft(2, '0')} '
      '${months[utc.month - 1]} ${utc.year}';
}
