abstract final class CacCardDates {
  static const Duration longestValidity = Duration(days: 3 * 366 + 31);

  static bool plausible(DateTime issuedOn, DateTime expiresOn) =>
      issuedOn.isBefore(expiresOn) &&
      !expiresOn.isAfter(issuedOn.add(longestValidity));

  static bool expiredAt(DateTime expiresOn, DateTime instant) =>
      utcDay(expiresOn).isBefore(utcDay(instant));

  static int daysBetween(DateTime from, DateTime to) =>
      utcDay(to).difference(utcDay(from)).inDays;

  static DateTime utcDay(DateTime instant) {
    final utc = instant.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }
}
