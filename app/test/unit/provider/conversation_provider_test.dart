import 'dart:async';
import 'dart:convert';

import 'package:localsend_app/model/persistence/conversation_entry.dart';
import 'package:localsend_app/provider/conversation_provider.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:test/test.dart';

import '../../fixtures/conversation_fixtures.dart';

void main() {
  late MemoryChatPersistence persistence;
  late RefenaContainer ref;
  late ConversationNotifier history;

  setUp(() {
    persistence = MemoryChatPersistence();
    ref = RefenaContainer(overrides: [persistenceProvider.overrideWithValue(persistence)]);
    history = ref.notifier(conversationProvider);
  });
  tearDown(() async {
    await history.flush();
    ref.disposeContainer();
  });

  test('sent and received entries persist and reload under the same certificate identity', () async {
    history.upsert(chatEntry('sent'));
    history.upsert(chatEntry('received', outgoing: false));
    await history.flush();
    final restored = persistence.saved.map((e) => ConversationEntry.fromJson(jsonDecode(jsonEncode(e.toJson())))).toList();
    expect(restored.map((e) => e.peerId).toSet(), {'peer'});
    expect(restored.map((e) => e.outgoing), [true, false]);
    expect(restored.map((e) => e.text), ['Hello', 'Hello']);
  });

  test('upsert is idempotent and per-file delivery updates do not change other messages', () async {
    history.upsert(chatEntry('one', delivery: ConversationDelivery.waiting));
    history.upsert(chatEntry('one', delivery: ConversationDelivery.waiting));
    history.upsert(chatEntry('two'));
    history.updateDelivery('one', ConversationDelivery.failed, error: 'connection refused');
    expect(history.state.length, 2);
    expect(history.state.first.error, 'connection refused');
    expect(history.state.last.delivery, ConversationDelivery.delivered);
  });

  test('terminal messages are not overwritten by session cancellation', () {
    final sent = chatEntry('one');
    history.upsert(sent);
    history.finishSession(sent.sessionId, outgoing: true, delivery: ConversationDelivery.cancelled);
    expect(history.state.single.delivery, ConversationDelivery.delivered);
  });

  test('disabled history keeps new content in memory without writing it to disk', () async {
    persistence.enabled = false;
    history.upsert(chatEntry('private'));
    await history.flush();
    expect(history.state.single.text, 'Hello');
    expect(persistence.writes, isEmpty);
  });

  test('clearing with history disabled does not persist previously unsaved content', () async {
    persistence.saved = [chatEntry('old-a'), chatEntry('old-b', peer: chatPeer('other'))];
    persistence.enabled = false;
    history.upsert(chatEntry('unsaved', peer: chatPeer('other')));
    history.clearPeer('peer');
    await history.flush();
    expect(persistence.saved.map((e) => e.id), ['old-b']);
  });

  test('writes are serialized so an older write cannot resurrect cleared history', () async {
    final firstWrite = Completer<void>();
    persistence.beforeSave = (_) => persistence.writes.length == 1 ? firstWrite.future : Future.value();
    history.upsert(chatEntry('one'));
    history.clearPeer('peer');
    await Future<void>.delayed(Duration.zero);
    expect(persistence.writes.length, 1);
    firstWrite.complete();
    await history.flush();
    expect(persistence.saved, isEmpty);
  });

  test('storage errors remain visible and a later successful save clears the error', () async {
    persistence.beforeSave = (_) => Future.error(StateError('disk full'));
    history.upsert(chatEntry('one'));
    await history.flush();
    expect(history.persistenceError, contains('disk full'));
    persistence.beforeSave = null;
    history.upsert(chatEntry('two'));
    await history.flush();
    expect(history.persistenceError, isNull);
    expect(persistence.saved.length, 2);
  });

  test('a claimed HTTP fingerprint cannot merge into a TLS conversation', () {
    expect(conversationPeerId(chatPeer('peer')), 'peer');
    expect(conversationPeerId(chatPeer('peer', https: false)), isNot('peer'));
    expect(conversationPeerId(chatPeer('peer', https: false)), isNot(conversationPeerId(chatPeer('peer', https: false, ip: '192.168.1.3'))));
  });

  test('loading changes only unfinished transfers to interrupted', () {
    final memory = MemoryChatPersistence(
      saved: [
        chatEntry('waiting', delivery: ConversationDelivery.waiting),
        chatEntry('done'),
      ],
    );
    final container = RefenaContainer(overrides: [persistenceProvider.overrideWithValue(memory)]);
    expect(container.read(conversationProvider).map((e) => e.delivery), [ConversationDelivery.interrupted, ConversationDelivery.delivered]);
    container.disposeContainer();
  });

  test('history is bounded while retaining the most recent entries', () async {
    final memory = MemoryChatPersistence(saved: [for (var i = 0; i < maxConversationEntries; i++) chatEntry('$i')]);
    final container = RefenaContainer(overrides: [persistenceProvider.overrideWithValue(memory)]);
    final notifier = container.notifier(conversationProvider);
    notifier.upsert(chatEntry('new'));
    await notifier.flush();
    expect(notifier.state.length, maxConversationEntries);
    expect(notifier.state.first.id, '1');
    expect(notifier.state.last.id, 'new');
    container.disposeContainer();
  });
}
