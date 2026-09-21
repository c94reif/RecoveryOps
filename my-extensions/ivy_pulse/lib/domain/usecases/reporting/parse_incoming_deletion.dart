import 'package:le_sdk/le_sdk.dart' as sdk;
import 'package:ivy_pulse/domain/services/report_codec.dart';

/// Decodes a mesh withdrawal notice, returning the entity id being pulled.
class ParseIncomingDeletion {
  final ReportCodec codec;

  const ParseIncomingDeletion(this.codec);

  String? call(sdk.IncomingMessage message) =>
      codec.decodeDeletion(message.payload);
}
