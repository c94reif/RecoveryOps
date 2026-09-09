import 'package:recovery_ops/domain/entities/parsed_recovery_request.dart';
import 'package:recovery_ops/domain/entities/recovery_request.dart';
import 'package:recovery_ops/domain/services/transcript_parser_strategy.dart';

class RegexTranscriptParser implements TranscriptParserStrategy {
  static final bumperPattern = RegExp(
    r'\b(?:[A-Za-z]+[-\s]?\d+[A-Za-z]?|\d+[A-Za-z]+[-\s]?\d*)\b',
  );

  static final wreckerPatterns = [
    RegExp(r'\bwrecker\b', caseSensitive: false),
    RegExp(r'\bheavy\s+recovery\b', caseSensitive: false),
    RegExp(r'\bflatbed\b', caseSensitive: false),
    RegExp(r'\bcrane\b', caseSensitive: false),
  ];

  static final towBarPatterns = [
    RegExp(r'\btow\s*bar\b', caseSensitive: false),
    RegExp(r'\btowing\b', caseSensitive: false),
    RegExp(r'\btow\s+it\b', caseSensitive: false),
    RegExp(r'\blight\s+recovery\b', caseSensitive: false),
    RegExp(r'\btow\s+strap\b', caseSensitive: false),
  ];

  static final typeKeywords = [
    ...wreckerPatterns,
    ...towBarPatterns,
  ];

  static final fillerPhrases = [
    RegExp(r"\bbumper\s+(number|#)\b", caseSensitive: false),
    RegExp(r"\bvehicle\s+(number|id|identifier)\b", caseSensitive: false),
    RegExp(r"\bvic\s+number\b", caseSensitive: false),
    RegExp(r"\bi'?m\s+in\s+need\s+of\s+a?\s*", caseSensitive: false),
    RegExp(r"\bi\s+need\s+a?\s*", caseSensitive: false),
    RegExp(r"\bwe\s+need\s+a?\s*", caseSensitive: false),
    RegExp(r"\bplease\s+send\s+a?\s*", caseSensitive: false),
    RegExp(r"\bsend\s+a?\s*", caseSensitive: false),
    RegExp(r"\brequesting\s+a?\s*", caseSensitive: false),
    RegExp(r"\brequest\s+a?\s*", caseSensitive: false),
    RegExp(r"\bhas\s+a\b", caseSensitive: false),
    RegExp(r"\bhas\s+an\b", caseSensitive: false),
    RegExp(r"\bgot\s+a\b", caseSensitive: false),
    RegExp(r"\bwith\s+a\b", caseSensitive: false),
    RegExp(r"\bdue\s+to\s+a?\s*", caseSensitive: false),
    RegExp(r"\bbecause\s+of\s+a?\s*", caseSensitive: false),
    RegExp(r"\band\b", caseSensitive: false),
    RegExp(r"\bfor\b", caseSensitive: false),
    RegExp(r"\bto\b", caseSensitive: false),
    RegExp(r"\bon\b", caseSensitive: false),
    RegExp(r"\bat\b", caseSensitive: false),
    RegExp(r"\bin\b", caseSensitive: false),
    RegExp(r"\bthe\b", caseSensitive: false),
    RegExp(r"\ba\b", caseSensitive: false),
    RegExp(r"\ban\b", caseSensitive: false),
    RegExp(r"\bit's\b", caseSensitive: false),
    RegExp(r"\bit\s+is\b", caseSensitive: false),
    RegExp(r"\bthat\s+is\b", caseSensitive: false),
    RegExp(r"\bwhich\s+is\b", caseSensitive: false),
    RegExp(r"\bis\s+down\b", caseSensitive: false),
    RegExp(r"\bis\s+broken\b", caseSensitive: false),
    RegExp(r"\bis\s+disabled\b", caseSensitive: false),
    RegExp(r"\bis\s+deadlined\b", caseSensitive: false),
    RegExp(r"\bis\s+non-?mission\s+capable\b", caseSensitive: false),
    RegExp(r"\bis\s+NMC\b"),
    RegExp(r"\bcan'?t\s+move\b", caseSensitive: false),
    RegExp(r"\bwon'?t\s+start\b", caseSensitive: false),
    RegExp(r"\bwill\s+not\s+start\b", caseSensitive: false),
    RegExp(r"\bis\s+not\s+running\b", caseSensitive: false),
  ];

  static final issueNormalizations = {
    RegExp(r"\bflat\b", caseSensitive: false): 'flat tire',
    RegExp(r"\bblown\s+tire\b", caseSensitive: false): 'flat tire',
    RegExp(r"\btire\s+blew\b", caseSensitive: false): 'flat tire',
    RegExp(r"\bpopped\s+tire\b", caseSensitive: false): 'flat tire',
    RegExp(r"\bdead\s+batt(?:ery)?\b", caseSensitive: false): 'dead battery',
    RegExp(r"\bbattery\s+is\s+dead\b", caseSensitive: false): 'dead battery',
    RegExp(r"\bno\s+start\b", caseSensitive: false): 'will not start',
    RegExp(r"\bengine\s+won'?t\s+turn\s+over\b", caseSensitive: false):
        'engine failure',
    RegExp(r"\boverheated?\b", caseSensitive: false): 'overheating',
    RegExp(r"\bover\s+heated?\b", caseSensitive: false): 'overheating',
    RegExp(r"\bstuck\b", caseSensitive: false): 'stuck',
    RegExp(r"\bbogged?\s+down\b", caseSensitive: false): 'stuck',
    RegExp(r"\bmired\b", caseSensitive: false): 'stuck',
  };

  @override
  Future<ParsedRecoveryRequest> parse(String transcript) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      return const ParsedRecoveryRequest(
        bumperNumber: '',
        issue: '',
      );
    }

    RecoveryType? recoveryType;
    for (final pattern in wreckerPatterns) {
      if (pattern.hasMatch(trimmed)) {
        recoveryType = RecoveryType.wrecker;
        break;
      }
    }
    if (recoveryType == null) {
      for (final pattern in towBarPatterns) {
        if (pattern.hasMatch(trimmed)) {
          recoveryType = RecoveryType.towBar;
          break;
        }
      }
    }

    final bumperMatch = bumperPattern.firstMatch(trimmed);
    final bumperNumber = bumperMatch?.group(0)?.replaceAll(' ', '-') ?? '';

    var issue = trimmed;
    if (bumperMatch != null) {
      issue = issue.replaceFirst(bumperMatch.group(0)!, '');
    }
    for (final pattern in typeKeywords) {
      issue = issue.replaceAll(pattern, '');
    }
    for (final filler in fillerPhrases) {
      issue = issue.replaceAll(filler, '');
    }

    issue = issue.replaceAll(RegExp(r'\s+'), ' ').trim();
    issue = issue.replaceAll(RegExp(r'^[\s,.\-;:]+|[\s,.\-;:]+$'), '');

    if (issue.isNotEmpty) {
      for (final entry in issueNormalizations.entries) {
        if (entry.key.hasMatch(issue)) {
          issue = entry.value;
          break;
        }
      }
    }

    return ParsedRecoveryRequest(
      bumperNumber: bumperNumber,
      issue: issue,
      recoveryType: recoveryType,
    );
  }
}
