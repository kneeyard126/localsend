import 'dart:async';

import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/model/persistence/conversation_entry.dart';
import 'package:localsend_app/provider/conversation_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/util/message_preview.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/file_type.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class ConversationJob {
  final String id;
  final Device peer;
  final List<CrossFile> files;
  final List<String> fileIds;

  ConversationJob({required this.id, required this.peer, required this.files, required this.fileIds});

  String get peerId => conversationPeerId(peer);
}

final conversationOutboxProvider = NotifierProvider<ConversationOutboxNotifier, List<ConversationJob>>((ref) {
  return ConversationOutboxNotifier(
    history: ref.notifier(conversationProvider),
    send: (job) async {
      final discovered = ref.read(nearbyDevicesProvider).allDevices[job.peer.fingerprint];
      final peer = discovered != null && discovered.https == job.peer.https && discovered.ip != null ? discovered : job.peer;
      await ref
          .notifier(sendProvider)
          .startSession(
            target: peer,
            files: job.files,
            background: true,
            conversationSessionId: job.id,
            conversationFileIds: job.fileIds,
          );
    },
    cancel: (id) => ref.notifier(sendProvider).cancelSession(id),
  );
});

/// Protocol v2 permits one incoming session per device. Queue per peer so
/// pressing Send again never loses a draft or starts a competing upload.
class ConversationOutboxNotifier extends Notifier<List<ConversationJob>> {
  final ConversationNotifier history;
  final Future<void> Function(ConversationJob) send;
  final void Function(String) cancel;
  final _runningPeers = <String>{};
  final _activeJobs = <String>{};
  final _retryFiles = <String, CrossFile>{};

  ConversationOutboxNotifier({required this.history, required this.send, required this.cancel});

  @override
  List<ConversationJob> init() => [];

  @override
  String describeState(List<ConversationJob> state) => '${state.length} outgoing jobs';

  void enqueue(Device peer, List<CrossFile> files) {
    if (files.isEmpty) return;
    if (state.length >= 50) throw StateError('The outgoing queue is full');
    final job = ConversationJob(id: _uuid.v4(), peer: peer, files: List.unmodifiable(files), fileIds: [for (final _ in files) _uuid.v4()]);
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final id = 'out:${job.id}:${job.fileIds[i]}';
      history.upsert(
        ConversationEntry(
          id: id,
          peer: peer,
          outgoing: true,
          timestamp: DateTime.now().toUtc(),
          delivery: ConversationDelivery.waiting,
          sessionId: job.id,
          fileId: job.fileIds[i],
          fileName: file.name,
          fileType: file.fileType,
          fileSize: file.size,
          text: files.length == 1 && file.fileType == FileType.text ? createMessagePreview(file.bytes) : null,
          path: file.path,
        ),
      );
      _retryFiles[id] = file;
    }
    // Bound retained in-memory clipboard payloads; disk-based attachments can
    // still be retried after restarting from the path saved in history.
    while (_retryFiles.length > 100 || _retryFiles.values.fold<int>(0, (size, file) => size + (file.bytes?.length ?? 0)) > 32 * 1024 * 1024) {
      _retryFiles.remove(_retryFiles.keys.first);
    }
    state = [...state, job];
    unawaited(_drain(job.peerId));
  }

  CrossFile? retryFile(String entryId) => _retryFiles[entryId];

  void cancelJob(String id) {
    history.finishSession(id, outgoing: true, delivery: ConversationDelivery.cancelled);
    if (_activeJobs.contains(id) || !state.any((job) => job.id == id)) {
      // The timeline also includes transfers started from the normal Send tab.
      // They have no queue job, but their transport still needs cancelling.
      cancel(id);
    } else {
      state = state.where((j) => j.id != id).toList();
    }
  }

  Future<void> _drain(String peerId) async {
    if (!_runningPeers.add(peerId)) return;
    try {
      while (state.any((j) => j.peerId == peerId)) {
        final job = state.firstWhere((j) => j.peerId == peerId);
        _activeJobs.add(job.id);
        try {
          await send(job);
        } catch (e) {
          history.finishSession(job.id, outgoing: true, delivery: ConversationDelivery.failed, error: e.toString());
        } finally {
          _activeJobs.remove(job.id);
          state = state.where((j) => j.id != job.id).toList();
        }
      }
    } finally {
      _runningPeers.remove(peerId);
    }
  }
}

final conversationAttachmentsProvider = NotifierProvider<ConversationAttachmentsNotifier, Map<String, List<CrossFile>>>(
  (ref) => ConversationAttachmentsNotifier(),
);

class ConversationAttachmentsNotifier extends Notifier<Map<String, List<CrossFile>>> {
  @override
  Map<String, List<CrossFile>> init() => {};

  @override
  String describeState(Map<String, List<CrossFile>> state) => '${state.length} attachment drafts';

  void add(String peerId, List<CrossFile> files) => state = {
    ...state,
    peerId: [...?state[peerId], ...files],
  };
  void remove(String peerId, int index) => state = {
    ...state,
    peerId: [...?state[peerId]]..removeAt(index),
  };
  void clear(String peerId) => state = {...state}..remove(peerId);
}

final conversationDraftsProvider = NotifierProvider<ConversationDraftsNotifier, Map<String, String>>((ref) => ConversationDraftsNotifier());

class ConversationDraftsNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> init() => {};

  @override
  String describeState(Map<String, String> state) => '${state.length} text drafts';

  void set(String peerId, String text) => state = {...state, peerId: text};
}
