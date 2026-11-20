import 'dart:async';

import 'package:localsend_app/model/persistence/conversation_entry.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

const maxConversationEntries = 1000;
final _logger = Logger('Conversations');

final conversationProvider = NotifierProvider<ConversationNotifier, List<ConversationEntry>>(
  (ref) => ConversationNotifier(ref.read(persistenceProvider)),
);

/// Selected independently of the widget so incoming messages can find their
/// conversation without constructing UI or changing the current route.
final selectedConversationProvider = NotifierProvider<SelectedConversationNotifier, Device?>(
  (ref) => SelectedConversationNotifier(),
);

class SelectedConversationNotifier extends Notifier<Device?> {
  @override
  Device? init() => null;

  void select(Device? device) => state = device;
}

class ConversationNotifier extends Notifier<List<ConversationEntry>> {
  final PersistenceService persistence;
  Future<void> _pendingSave = Future.value();
  String? persistenceError;

  ConversationNotifier(this.persistence);

  @override
  List<ConversationEntry> init() {
    // A process restart cannot resume an HTTP session. Preserve its content,
    // but never leave yesterday's transfer showing an endless progress bar.
    return persistence.getConversationHistory().map((entry) {
      return entry.inFlight ? entry.copyWith(delivery: ConversationDelivery.interrupted) : entry;
    }).toList();
  }

  @override
  String describeState(List<ConversationEntry> state) => '${state.length} conversation entries';

  void upsert(ConversationEntry entry) {
    final index = state.indexWhere((e) => e.id == entry.id);
    final updated = [...state];
    if (index == -1) {
      updated.add(entry);
    } else {
      updated[index] = entry;
    }
    _commit(updated.skip((updated.length - maxConversationEntries).clamp(0, updated.length)).toList());
  }

  void updateDelivery(String id, ConversationDelivery delivery, {String? path, String? fileName, bool? savedToGallery, String? error}) {
    if (!state.any((e) => e.id == id)) return;
    _commit([
      for (final e in state)
        if (e.id == id)
          e.copyWith(
            delivery: delivery,
            path: path ?? e.path,
            fileName: fileName ?? e.fileName,
            savedToGallery: savedToGallery ?? e.savedToGallery,
            error: error,
          )
        else
          e,
    ]);
  }

  void finishSession(String sessionId, {required bool outgoing, required ConversationDelivery delivery, String? error}) {
    final ids = state.where((e) => e.sessionId == sessionId && e.outgoing == outgoing && e.inFlight).map((e) => e.id).toSet();
    if (ids.isEmpty) return;
    _commit([
      for (final e in state) ids.contains(e.id) ? e.copyWith(delivery: delivery, error: error) : e,
    ]);
  }

  void clearPeer(String peerId) {
    state = List.unmodifiable(state.where((e) => e.peerId != peerId));
    final saved = persistence.isSaveToHistory() ? state : persistence.getConversationHistory().where((e) => e.peerId != peerId).toList();
    _save(saved);
  }

  void _commit(List<ConversationEntry> entries) {
    state = List.unmodifiable(entries);
    if (!persistence.isSaveToHistory()) return;
    _save(state);
  }

  void _save(List<ConversationEntry> snapshot) {
    // Serialize writes. A slower previous write must not replace a newer
    // delivered state or resurrect a conversation after the user clears it.
    _pendingSave = _pendingSave
        .then((_) => persistence.setConversationHistory(snapshot))
        .then((_) {
          if (persistenceError != null) {
            persistenceError = null;
            state = List.unmodifiable(state);
          }
        })
        .catchError((Object e, StackTrace st) {
          persistenceError = e.toString();
          _logger.warning('Could not save conversation history', e, st);
          state = List.unmodifiable(state);
        });
  }

  Future<void> flush() => _pendingSave;
}
