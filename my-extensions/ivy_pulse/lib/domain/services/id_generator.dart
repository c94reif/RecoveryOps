/// Injectable identifier source, so use cases that mint session and entity ids
/// stay deterministic under test.
abstract class IdGenerator {
  String newId();
}
