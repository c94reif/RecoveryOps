enum CacRejection {
  nameNotFound,

  noCodeFound,

  codeUnreadable,

  cardTooSmall,

  notACac,

  wrongSideOfCard,

  legacySsnCard,

  expired,

  cancelled,

  cameraTimedOut,

  noCamera;

  String get message => switch (this) {
        CacRejection.nameNotFound =>
          'No name found. Scan the front of the card — the side with your '
              'photo — and hold the printed name steady.',
        CacRejection.noCodeFound =>
          'Could not read the complete 10-digit DoD ID number. Rescan the '
              'back of your CAC — fill the frame with the side with the '
              'wide barcode strip and hold all 10 digits steady.',
        CacRejection.codeUnreadable =>
          'Could not read all 10 digits of the DoD ID number. Rescan the '
              'back of your CAC — wipe the card, tilt it away from the '
              'light, and hold the full number steady.',
        CacRejection.cardTooSmall =>
          'The card is too small in the frame. Move closer until the DoD ID '
              'number is clear.',
        CacRejection.notACac =>
          'That is not a CAC. Scan the back of the card — the side with the '
              'wide barcode strip and the DoD ID number.',
        CacRejection.wrongSideOfCard =>
          'That is the side with your photo. Turn it over — the DoD ID number is '
              'printed on the back, above the wide barcode strip.',
        CacRejection.legacySsnCard =>
          'That card predates 2012 and carries an SSN. It cannot be used — '
              'draw a current CAC.',
        CacRejection.expired => 'That CAC expired. Draw a current card.',
        CacRejection.cancelled => 'Scan cancelled.',
        CacRejection.cameraTimedOut =>
          'The camera did not come back. Try again.',
        CacRejection.noCamera =>
          'No camera available on this device. Scan on a device that has one.',
      };

  bool get isWorthRetrying => switch (this) {
        CacRejection.nameNotFound ||
        CacRejection.noCodeFound ||
        CacRejection.codeUnreadable ||
        CacRejection.cardTooSmall ||
        CacRejection.notACac ||
        CacRejection.wrongSideOfCard ||
        CacRejection.cancelled ||
        CacRejection.cameraTimedOut =>
          true,
        CacRejection.legacySsnCard ||
        CacRejection.expired ||
        CacRejection.noCamera =>
          false,
      };
}
