import 'package:uuid/uuid.dart';
import 'package:ivy_pulse/domain/services/id_generator.dart';

/// UUID v4 identifiers, unique across devices with no coordination — which is
/// the only option on a disconnected mesh.
class UuidIdGenerator implements IdGenerator {
  final Uuid _uuid;

  UuidIdGenerator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  @override
  String newId() => _uuid.v4();
}
