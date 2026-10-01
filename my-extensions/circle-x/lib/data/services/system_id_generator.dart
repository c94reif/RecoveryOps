import 'package:uuid/uuid.dart';
import 'package:circle_x/domain/services/id_generator.dart';

class UuidIdGenerator implements IdGenerator {
  final Uuid _uuid;

  UuidIdGenerator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  @override
  String newId() => _uuid.v4();
}
