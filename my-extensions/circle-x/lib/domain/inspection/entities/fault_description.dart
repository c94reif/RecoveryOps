import 'package:characters/characters.dart';

const int maxFaultDescriptionLength = 155;

String? normalizeFaultDescription(String? description) {
  final trimmed = description?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  if (trimmed.characters.length > maxFaultDescriptionLength) {
    throw ArgumentError('Fault descriptions must be 155 characters or fewer');
  }
  return trimmed;
}
