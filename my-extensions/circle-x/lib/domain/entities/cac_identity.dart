class CacIdentity {
  final String edipi;

  final String firstName;
  final String lastName;

  final String middleInitial;

  final String rank;

  final String branchCode;

  final String categoryCode;

  final DateTime? cardExpiresOn;

  final String cardInstance;

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

  static const int expiryWarningDays = 30;

  int? get daysUntilCardExpiry {
    final expiresOn = cardExpiresOn;
    if (expiresOn == null) return null;

    return _utcDay(expiresOn).difference(_utcDay(verifiedAt)).inDays;
  }

  bool get isCardExpiringSoon {
    final days = daysUntilCardExpiry;
    return days != null && days <= expiryWarningDays;
  }

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

  static CacIdentity? fromMap(Map<String, Object?> map) {
    final edipi = map['edipi'];
    final verifiedAt = map['verifiedAt'];
    final expiresOn = map['cardExpiresOn'];
    if (!isValidEdipi(edipi) ||
        map['firstName'] is! String ||
        map['lastName'] is! String ||
        verifiedAt is! String ||
        DateTime.tryParse(verifiedAt) == null ||
        (expiresOn != null &&
            (expiresOn is! String || DateTime.tryParse(expiresOn) == null)) ||
        ['middleInitial', 'rank', 'branchCode', 'categoryCode', 'cardInstance']
            .any((key) => map.containsKey(key) && map[key] is! String)) {
      return null;
    }

    return CacIdentity(
      edipi: edipi as String,
      firstName: map['firstName'] as String,
      lastName: map['lastName'] as String,
      middleInitial: map['middleInitial'] as String? ?? '',
      rank: map['rank'] as String? ?? '',
      branchCode: map['branchCode'] as String? ?? '',
      categoryCode: map['categoryCode'] as String? ?? '',
      cardExpiresOn: expiresOn == null
          ? null
          : DateTime.parse(expiresOn as String).toUtc(),
      cardInstance: map['cardInstance'] as String? ?? '',
      verifiedAt: DateTime.parse(verifiedAt).toUtc(),
    );
  }

  static bool isValidEdipi(Object? value) =>
      value is String &&
      value.length == 10 &&
      RegExp(r'^[1-9][0-9]{9}$').hasMatch(value);
}
