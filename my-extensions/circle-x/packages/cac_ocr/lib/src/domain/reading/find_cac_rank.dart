import 'package:cac_ocr/src/domain/reading/printed_field.dart';

String? findCacRank(Iterable<String> rawLines) => readLabelledField(
      normalizedCacLines(rawLines),
      _label,
      (rest, below) =>
          (rest.isEmpty ? null : _leadingRank(rest)) ??
          (below == null ? null : _leadingRank(below)),
    );

final _label = RegExp(r'^RANK\b\s*[:\-]?\s*');

String? _leadingRank(String value) {
  final words = value.split(' ');
  return _rankOf(words.take(2).join()) ?? _rankOf(words.first);
}

String? _rankOf(String value) {
  final rank = value.replaceAll(RegExp(r'[\s.]'), '');
  return _ranks.contains(rank) ? rank : null;
}

const _ranks = {
  'PVT', 'PV1', 'PV2', 'PFC', 'SPC', 'CPL', 'SGT', 'SSG', 'SFC', 'MSG', '1SG',
  'SGM', 'CSM', 'SMA', 'WO1', 'CW2', 'CW3', 'CW4', 'CW5', '2LT', '1LT', 'CPT',
  'MAJ', 'LTC', 'COL', 'BG', 'MG', 'LTG', 'GEN',
  'LCPL', 'SSGT', 'GYSGT', 'MSGT', '1STSGT', 'MGYSGT', 'SGTMAJ', 'SMMC', 'WO',
  'CWO2', 'CWO3', 'CWO4', 'CWO5', '2NDLT', '1STLT', 'CAPT', 'LTCOL', 'BGEN',
  'MAJGEN', 'LTGEN',
  'SR', 'SA', 'SN', 'FR', 'FA', 'FN', 'AR', 'AA', 'AN', 'HR', 'HA', 'HN', 'PO3',
  'PO2', 'PO1', 'CPO', 'SCPO', 'MCPO', 'MCPON', 'MCPOCG', 'ENS', 'LTJG', 'LT',
  'LCDR', 'CDR', 'RDML', 'RADM', 'VADM', 'ADM',
  'AB', 'AMN', 'A1C', 'SRA', 'TSGT', 'SMSGT', 'CMSGT', 'CMSAF', 'CMSSF',
  'SPC1', 'SPC2', 'SPC3', 'SPC4', '2DLT', 'BRIGGEN',
};
