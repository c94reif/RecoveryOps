class IncomingReportMessage {
  final String payload;
  final String fromCallsign;

  const IncomingReportMessage({required this.payload, this.fromCallsign = ''});
}
