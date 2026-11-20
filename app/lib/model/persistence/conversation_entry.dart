import 'package:dart_mappable/dart_mappable.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/file_type.dart';

part 'conversation_entry.mapper.dart';

/// Plain HTTP carries no authenticated certificate. Keep those conversations
/// separate so a claimed fingerprint cannot merge into a verified TLS chat.
String conversationPeerId(Device peer) => peer.https ? peer.fingerprint : 'http:${peer.ip}:${peer.port}:${peer.fingerprint}';

@MappableEnum()
enum ConversationDelivery { waiting, sending, delivered, failed, declined, cancelled, interrupted }

@MappableClass()
class ConversationEntry with ConversationEntryMappable {
  final String id;
  final Device peer;
  final bool outgoing;
  final DateTime timestamp;
  final ConversationDelivery delivery;
  final String sessionId;
  final String fileId;
  final String fileName;
  final FileType fileType;
  final int fileSize;
  final String? text;
  final String? path;
  final bool savedToGallery;
  final String? error;

  const ConversationEntry({
    required this.id,
    required this.peer,
    required this.outgoing,
    required this.timestamp,
    required this.delivery,
    required this.sessionId,
    required this.fileId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.text,
    required this.path,
    this.savedToGallery = false,
    this.error,
  });

  bool get inFlight => delivery == ConversationDelivery.waiting || delivery == ConversationDelivery.sending;
  String get peerId => conversationPeerId(peer);

  static const fromJson = ConversationEntryMapper.fromJson;

  // Never print message contents, paths or peer addresses in debug observers.
  @override
  String toString() => 'ConversationEntry(id: $id, outgoing: $outgoing, delivery: $delivery)';
}
