import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/model/persistence/conversation_entry.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/file_type.dart';
import 'package:mockito/mockito.dart';

Device chatPeer(String fingerprint, {bool https = true, String ip = '192.168.1.2'}) => Device(
  signalingId: null,
  ip: ip,
  version: '2.2',
  port: 53317,
  https: https,
  fingerprint: fingerprint,
  alias: fingerprint,
  deviceModel: 'Test device',
  deviceType: DeviceType.desktop,
  download: false,
  channels: [HttpChannel(host: ip, port: 53317, https: https)],
);

ConversationEntry chatEntry(
  String id, {
  Device? peer,
  bool outgoing = true,
  ConversationDelivery delivery = ConversationDelivery.delivered,
  String? text = 'Hello',
}) => ConversationEntry(
  id: id,
  peer: peer ?? chatPeer('peer'),
  outgoing: outgoing,
  timestamp: DateTime.utc(2026, 11, 20),
  delivery: delivery,
  sessionId: 'session-$id',
  fileId: 'file-$id',
  fileName: '$id.txt',
  fileType: FileType.text,
  fileSize: 5,
  text: text,
  path: null,
);

CrossFile chatFile(String name) => CrossFile(
  name: name,
  fileType: FileType.text,
  size: 5,
  thumbnail: null,
  asset: null,
  path: null,
  bytes: [72, 101, 108, 108, 111],
  lastModified: null,
  lastAccessed: null,
);

class MemoryChatPersistence extends Fake implements PersistenceService {
  List<ConversationEntry> saved;
  bool enabled;
  final writes = <List<ConversationEntry>>[];
  Future<void> Function(List<ConversationEntry>)? beforeSave;

  MemoryChatPersistence({this.saved = const [], this.enabled = true});

  @override
  bool isSaveToHistory() => enabled;

  @override
  List<ConversationEntry> getConversationHistory() => saved;

  @override
  Future<void> setConversationHistory(List<ConversationEntry> entries) async {
    writes.add(entries);
    await beforeSave?.call(entries);
    saved = List.unmodifiable(entries);
  }
}
