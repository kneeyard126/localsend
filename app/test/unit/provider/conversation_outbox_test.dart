import 'dart:async';

import 'package:localsend_app/model/persistence/conversation_entry.dart';
import 'package:localsend_app/provider/conversation_outbox_provider.dart';
import 'package:localsend_app/provider/conversation_provider.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:test/test.dart';

import '../../fixtures/conversation_fixtures.dart';

void main() {
  late RefenaContainer ref;
  late ConversationNotifier history;
  late ConversationOutboxNotifier outbox;
  late List<ConversationJob> calls;
  late List<String> cancelled;
  late Map<String, Completer<void>> pending;

  setUp(() {
    calls = [];
    cancelled = [];
    pending = {};
    ref = RefenaContainer(
      overrides: [
        persistenceProvider.overrideWithValue(MemoryChatPersistence(enabled: false)),
        conversationOutboxProvider.overrideWithNotifier(
          (ref) => ConversationOutboxNotifier(
            history: ref.notifier(conversationProvider),
            send: (job) async {
              calls.add(job);
              final wait = Completer<void>();
              pending[job.id] = wait;
              await wait.future;
              ref.notifier(conversationProvider).finishSession(job.id, outgoing: true, delivery: ConversationDelivery.delivered);
            },
            cancel: (id) {
              cancelled.add(id);
              pending[id]?.complete();
            },
          ),
        ),
      ],
    );
    history = ref.notifier(conversationProvider);
    outbox = ref.notifier(conversationOutboxProvider);
  });
  tearDown(() async {
    // Remove queued work before completing active jobs.
    for (final job in [...outbox.state]) {
      outbox.cancelJob(job.id);
    }
    await Future<void>.delayed(Duration.zero);
    await history.flush();
    ref.disposeContainer();
  });

  test('consecutive sends to one peer are serialized and immediately visible in history', () async {
    outbox.enqueue(chatPeer('one'), [chatFile('first')]);
    outbox.enqueue(chatPeer('one'), [chatFile('second')]);
    expect(calls.length, 1);
    expect(history.state.map((e) => e.fileName), ['first', 'second']);
    pending[calls.first.id]!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(calls.length, 2);
    expect(calls.last.files.single.name, 'second');
  });

  test('different recipients can progress independently', () {
    outbox.enqueue(chatPeer('one'), [chatFile('first')]);
    outbox.enqueue(chatPeer('two'), [chatFile('second')]);
    expect(calls.length, 2);
  });

  test('cancelling a queued message never submits it to the transport', () async {
    outbox.enqueue(chatPeer('one'), [chatFile('first')]);
    outbox.enqueue(chatPeer('one'), [chatFile('second')]);
    final queued = outbox.state.last;
    outbox.cancelJob(queued.id);
    expect(history.state.last.delivery, ConversationDelivery.cancelled);
    pending[calls.first.id]!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(calls.length, 1);
  });

  test('cancelling an active message invokes transport cancellation and keeps the terminal state', () async {
    outbox.enqueue(chatPeer('one'), [chatFile('first')]);
    final id = calls.single.id;
    outbox.cancelJob(id);
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, [id]);
    expect(history.state.single.delivery, ConversationDelivery.cancelled);
  });

  test('a failed request does not lose the next message', () async {
    outbox.enqueue(chatPeer('one'), [chatFile('first')]);
    outbox.enqueue(chatPeer('one'), [chatFile('second')]);
    pending[calls.first.id]!.completeError(StateError('unreachable'));
    await Future<void>.delayed(Duration.zero);
    expect(history.state.first.delivery, ConversationDelivery.failed);
    expect(calls.last.files.single.name, 'second');
    expect(outbox.retryFile(history.state.first.id)?.bytes, chatFile('first').bytes);
  });

  test('a transfer started outside the chat queue still cancels its transport', () {
    final entry = chatEntry('normal-send', delivery: ConversationDelivery.sending);
    history.upsert(entry);
    outbox.cancelJob(entry.sessionId);
    expect(cancelled, [entry.sessionId]);
    expect(history.state.single.delivery, ConversationDelivery.cancelled);
  });
}
