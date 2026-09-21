/// The Soldier who closed a PMCS out, read off the PDF417 on the front of
/// their CAC — the tall block in the lower-left corner beside the gold chip,
/// not the wide Code 39 strip on the back, which carries no name and no rank
/// and cannot produce one of these at all.
///
/// Deliberately narrower than the barcode. The card also carries a date of
/// birth and, on cards issued before 1 December 2012, the cardholder's SSN in
/// the Person Designator Identifier. Neither tells a maintainer anything about
/// who signed for a vehicle, and DoD guidance treats a DoD ID number *paired
/// with a date of birth* as a reportable combination — so the parser reads
/// those fields to validate the record and then drops them on the floor. What
/// is kept here is what goes on a 5988-E signature block and nothing else.
class CacIdentity {
  /// DoD ID number — ten digits, zero-padded, kept as a string because that
  /// is how DEERS and every downstream Army system treat it.
  final String edipi;

  final String firstName;
  final String lastName;

  /// Single letter, or empty on a legacy version-`1` card that has no room
  /// for one.
  final String middleInitial;

  /// Rank abbreviation exactly as the card prints it — `SGT`, `TSGT`, `MAJ`.
  /// Display only: the card's own pay-plan codes are the authority on grade.
  final String rank;

  /// Single-character service code off the card: `A` Army, `F` Air Force,
  /// `M` Marine Corps, `N` Navy, `C` Coast Guard, `D` DoD.
  final String branchCode;

  /// Single-character Personnel Category Code — active duty, Guard, Reserve,
  /// civilian, contractor. A maintainer reads a contractor signature
  /// differently from an active-duty one.
  final String categoryCode;

  /// Card expiry. An expired card is refused at the scan, so on a stored
  /// identity this is always in the future as of the moment it was scanned.
  final DateTime? cardExpiresOn;

  /// Machine-generated character distinguishing this card from other cards
  /// issued to the same Soldier. A weak tamper signal — if the same EDIPI
  /// starts arriving under a different instance, the card was reissued.
  final String cardInstance;

  /// When the scan happened, not when the PMCS was submitted. The two differ
  /// if a queued submission drains later.
  final DateTime verifiedAt;

  const CacIdentity({
    required this.edipi,
    required this.firstName,
    required this.lastName,
    this.middleInitial = '',
    this.rank = '',
    this.branchCode = '',
    this.categoryCode = '',
    this.cardExpiresOn,
    this.cardInstance = '',
    required this.verifiedAt,
  });

  /// `SGT SMITH, JOHN A` — the signature block a maintainer reads.
  String get displayName {
    final surname = lastName.isEmpty ? '' : lastName;
    final given = [
      if (firstName.isNotEmpty) firstName,
      if (middleInitial.isNotEmpty) middleInitial,
    ].join(' ');

    final name = switch ((surname.isNotEmpty, given.isNotEmpty)) {
      (true, true) => '$surname, $given',
      (true, false) => surname,
      (false, true) => given,
      (false, false) => 'DoD ID $edipi',
    };

    return rank.isEmpty ? name : '$rank $name';
  }

  /// Service the card was issued by, for the report card. Falls back to the
  /// raw code rather than guessing — the 2012 barcode spec predates the Space
  /// Force and a code this build does not know is still worth showing.
  String get branch => switch (branchCode) {
        'A' => 'US Army',
        'C' => 'US Coast Guard',
        'D' => 'DoD',
        'F' => 'US Air Force',
        'H' => 'US Public Health Service',
        'M' => 'US Marine Corps',
        'N' => 'US Navy',
        'O' => 'NOAA',
        '' => '',
        _ => branchCode,
      };

  /// Enough of the Personnel Category Code to tell a maintainer whether they
  /// are reading a Soldier's signature or a contractor's.
  String get category => switch (categoryCode) {
        'A' => 'Active Duty',
        'C' => 'DoD Civilian',
        'E' => 'DoD Contractor',
        'I' => 'Non-DoD Civilian',
        'N' => 'National Guard',
        'O' => 'Non-DoD Contractor',
        'R' => 'Retired',
        'V' => 'Reserve',
        'W' => 'DoD Beneficiary',
        '' => '',
        _ => categoryCode,
      };

  /// How far out the operator is warned that their card is running out.
  ///
  /// Thirty days is the window a Soldier can actually act inside — an ID card
  /// appointment is rarely same-week, and a card that dies mid-rotation
  /// strands whoever has been signing the 5988-Es.
  static const int expiryWarningDays = 30;

  /// Whole days from the scan to the card's expiry, or null on a card that
  /// carried no expiry field.
  ///
  /// Measured against [verifiedAt] rather than a fresh clock on purpose.
  /// [verifiedAt] is already the scan instant off the injected clock, so this
  /// needs no clock of its own: the domain keeps one time source, and the
  /// arithmetic stays deterministic under a fixed clock. Both ends are cut
  /// back to UTC calendar days because a card expires on a day, not at an
  /// instant — without that, a card scanned at 23:00 reads a day short.
  int? get daysUntilCardExpiry {
    final expiresOn = cardExpiresOn;
    if (expiresOn == null) return null;

    return _utcDay(expiresOn).difference(_utcDay(verifiedAt)).inDays;
  }

  /// True inside the warning window, and on a card already past its date.
  ///
  /// The scan refuses an expired card outright, so the past case only reaches
  /// here through an identity restored from an older report — and a
  /// maintainer reading that signature block still wants to be told.
  bool get isCardExpiringSoon {
    final days = daysUntilCardExpiry;
    return days != null && days <= expiryWarningDays;
  }

  /// The tail of "Expires ___": `today`, `tomorrow`, `in 12 days`. Empty when
  /// the card carries no expiry date, and `expired` on one already past it.
  String get cardExpiryCountdown {
    final days = daysUntilCardExpiry;
    if (days == null) return '';

    return switch (days) {
      < 0 => 'expired',
      0 => 'today',
      1 => 'tomorrow',
      _ => 'in $days days',
    };
  }

  /// Midnight UTC on the day [instant] falls on.
  static DateTime _utcDay(DateTime instant) {
    final utc = instant.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  Map<String, Object?> toMap() => {
        'edipi': edipi,
        'firstName': firstName,
        'lastName': lastName,
        if (middleInitial.isNotEmpty) 'middleInitial': middleInitial,
        if (rank.isNotEmpty) 'rank': rank,
        if (branchCode.isNotEmpty) 'branchCode': branchCode,
        if (categoryCode.isNotEmpty) 'categoryCode': categoryCode,
        if (cardExpiresOn != null)
          'cardExpiresOn': cardExpiresOn!.toUtc().toIso8601String(),
        if (cardInstance.isNotEmpty) 'cardInstance': cardInstance,
        'verifiedAt': verifiedAt.toUtc().toIso8601String(),
      };

  /// Null for anything that is not a usable identity. A report from a build
  /// that predates CAC verification has no identity at all, and one written
  /// by a newer build may carry fields this one does not know — neither is a
  /// reason to drop the report.
  static CacIdentity? fromMap(Map<String, Object?> map) {
    final edipi = map['edipi'];
    if (edipi is! String || edipi.isEmpty) return null;

    return CacIdentity(
      edipi: edipi,
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      middleInitial: map['middleInitial'] as String? ?? '',
      rank: map['rank'] as String? ?? '',
      branchCode: map['branchCode'] as String? ?? '',
      categoryCode: map['categoryCode'] as String? ?? '',
      cardExpiresOn:
          DateTime.tryParse(map['cardExpiresOn'] as String? ?? '')?.toUtc(),
      cardInstance: map['cardInstance'] as String? ?? '',
      verifiedAt:
          DateTime.tryParse(map['verifiedAt'] as String? ?? '')?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
