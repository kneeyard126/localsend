import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/model/persistence/conversation_entry.dart';
import 'package:localsend_app/pages/device_details_page.dart';
import 'package:localsend_app/provider/conversation_outbox_provider.dart';
import 'package:localsend_app/provider/conversation_provider.dart';
import 'package:localsend_app/provider/file_transfer_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/scan_facade.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/message_preview.dart';
import 'package:localsend_app/util/native/conversation_picker.dart';
import 'package:localsend_app/util/native/cross_file_converters.dart';
import 'package:localsend_app/util/native/file_picker.dart';
import 'package:localsend_app/util/native/open_file.dart';
import 'package:localsend_app/util/ui/snackbar.dart';
import 'package:localsend_app/widget/dialogs/address_input_dialog.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/file_type.dart';
import 'package:localsend_isolates/util/file_size_helper.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:url_launcher/url_launcher.dart';

class ConversationsTab extends StatefulWidget {
  const ConversationsTab({super.key});

  @override
  State<ConversationsTab> createState() => _ConversationsTabState();
}

class _ConversationsTabState extends State<ConversationsTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final entries = context.watch(conversationProvider);
    final nearby = context.watch(nearbyDevicesProvider).allDevices;
    final selected = context.watch(selectedConversationProvider);
    final peers = <String, Device>{};
    for (final entry in entries.reversed) {
      peers.putIfAbsent(entry.peerId, () => entry.peer);
    }
    for (final peer in nearby.values.where((d) => d.ip != null)) {
      peers[conversationPeerId(peer)] = peer;
    }
    if (selected != null) peers.putIfAbsent(conversationPeerId(selected), () => selected);
    final filtered = peers.entries.where((item) {
      final q = _query.trim().toLowerCase();
      return q.isEmpty ||
          item.value.alias.toLowerCase().contains(q) ||
          entries.any((e) => e.peerId == item.key && '${e.text ?? ''} ${e.fileName}'.toLowerCase().contains(q));
    }).toList();
    final current = selected == null ? null : peers[conversationPeerId(selected)] ?? selected;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final list = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.conversations.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        Text(t.conversations.subtitle, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: t.conversations.newConversation,
                    icon: const Icon(Icons.add_comment_outlined),
                    onPressed: () async {
                      final device = await showDialog<Device>(context: context, builder: (_) => const AddressInputDialog());
                      if (device != null && context.mounted) context.ref.notifier(selectedConversationProvider).select(device);
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: t.conversations.search,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 22, right: 10),
              child: Row(
                children: [
                  Expanded(child: Text(t.conversations.history, style: Theme.of(context).textTheme.labelMedium)),
                  IconButton(
                    tooltip: t.sendTab.scan,
                    icon: const Icon(Icons.refresh_rounded, size: 21),
                    onPressed: () => context.global.dispatchAsync(StartSmartScan()),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(peers.isEmpty ? t.conversations.emptyHint : t.conversations.noResults, textAlign: TextAlign.center),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final last = entries.where((e) => e.peerId == item.key).lastOrNull;
                        final found = nearby.values.any((d) => conversationPeerId(d) == item.key);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Material(
                            color: current != null && conversationPeerId(current) == item.key
                                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .55)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              leading: _DeviceAvatar(device: item.value),
                              title: Text(
                                item.value.alias,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                last == null
                                    ? (found ? t.conversations.discovered : t.conversations.lastAddress)
                                    : last.text?.replaceAll('\n', ' ') ?? last.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: last == null ? null : Text(_time(last.timestamp), style: Theme.of(context).textTheme.labelSmall),
                              onTap: () => context.ref.notifier(selectedConversationProvider).select(item.value),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(t.conversations.localHistoryHint, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
            ),
          ],
        );
        final pane = current == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.forum_outlined, size: 54, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(height: 24),
                      Text(t.conversations.emptyTitle, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 10),
                      Text(t.conversations.emptyHint, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              )
            : ConversationPane(key: ValueKey(conversationPeerId(current)), device: current, compact: compact);
        if (compact) return current == null ? list : pane;
        return Row(
          children: [
            SizedBox(width: 300, child: list),
            const VerticalDivider(width: 1),
            Expanded(child: pane),
          ],
        );
      },
    );
  }
}

class ConversationPane extends StatefulWidget {
  final Device device;
  final bool compact;

  const ConversationPane({required this.device, required this.compact, super.key});

  @override
  State<ConversationPane> createState() => _ConversationPaneState();
}

class _ConversationPaneState extends State<ConversationPane> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _inputFocus = FocusNode();
  String? _lastId;
  bool _searching = false;
  String _search = '';

  String get peerId => conversationPeerId(widget.device);

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _send() {
    final ref = context.ref;
    final text = _text.text;
    final attachments = ref.read(conversationAttachmentsProvider)[peerId] ?? [];
    if (text.trim().isEmpty && attachments.isEmpty) return;
    final jobs = (text.trim().isEmpty ? 0 : 1) + (attachments.isEmpty ? 0 : 1);
    if (ref.read(conversationOutboxProvider).length + jobs > 50) {
      context.showSnackBar(t.conversations.queueFull);
      return;
    }
    final outbox = ref.notifier(conversationOutboxProvider);
    if (text.trim().isNotEmpty) {
      final bytes = utf8.encode(text);
      outbox.enqueue(widget.device, [
        CrossFile(
          name: 'message-${DateTime.now().millisecondsSinceEpoch}.txt',
          fileType: FileType.text,
          size: bytes.length,
          thumbnail: null,
          asset: null,
          path: null,
          bytes: bytes,
          lastModified: null,
          lastAccessed: null,
        ),
      ]);
    }
    if (attachments.isNotEmpty) outbox.enqueue(widget.device, attachments);
    ref.notifier(conversationDraftsProvider).set(peerId, '');
    ref.notifier(conversationAttachmentsProvider).clear(peerId);
    _text.clear();
    _inputFocus.requestFocus();
  }

  Future<void> _attach(FilePickerOption option) async {
    try {
      final files = await pickConversationAttachments(context, option);
      if (!mounted) return;
      if (option == FilePickerOption.clipboard && files.length == 1 && files.single.fileType == FileType.text) {
        final preview = createMessagePreview(files.single.bytes);
        if (preview != null) {
          _text.text += preview;
          context.ref.notifier(conversationDraftsProvider).set(peerId, _text.text);
          return;
        }
      }
      context.ref.notifier(conversationAttachmentsProvider).add(peerId, files);
    } catch (e) {
      if (mounted) context.showSnackBar(t.conversations.sourceUnavailable);
    }
  }

  Future<void> _retry(ConversationEntry entry) async {
    final ref = context.ref;
    CrossFile? file = ref.notifier(conversationOutboxProvider).retryFile(entry.id);
    if (file == null && entry.text != null) {
      final bytes = utf8.encode(entry.text!);
      file = CrossFile(
        name: entry.fileName,
        fileType: FileType.text,
        size: bytes.length,
        thumbnail: null,
        asset: null,
        path: null,
        bytes: bytes,
        lastModified: null,
        lastAccessed: null,
      );
    }
    if (file == null && entry.path != null && !entry.path!.startsWith('content://')) {
      final source = File(entry.path!);
      if (await source.exists()) file = await CrossFileConverters.convertFile(source);
    }
    if (!mounted) return;
    if (file == null) {
      context.showSnackBar(t.conversations.sourceUnavailable);
      return;
    }
    try {
      ref.notifier(conversationOutboxProvider).enqueue(widget.device, [file]);
    } catch (_) {
      context.showSnackBar(t.conversations.queueFull);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final all = ref.watch(conversationProvider);
    final entries = all.where((e) => e.peerId == peerId).toList();
    final visible = _search.trim().isEmpty
        ? entries
        : entries.where((e) => '${e.text ?? ''} ${e.fileName}'.toLowerCase().contains(_search.toLowerCase())).toList();
    final drafts = ref.watch(conversationDraftsProvider);
    final savedDraft = drafts[peerId] ?? '';
    if (_text.text != savedDraft) {
      // Global paste can update the draft while this input still has focus.
      // Keep the controller in sync so Send never submits the previous text.
      _text.value = TextEditingValue(
        text: savedDraft,
        selection: TextSelection.collapsed(offset: savedDraft.length),
      );
    }
    final attachments = ref.watch(conversationAttachmentsProvider)[peerId] ?? [];
    final jobs = ref.watch(conversationOutboxProvider).where((j) => j.peerId == peerId).toList();
    final transfer = ref.watch(fileTransferProvider);
    final settings = ref.watch(settingsProvider);
    final saveError = ref.notifier(conversationProvider).persistenceError;
    final last = visible.lastOrNull;
    if (last?.id != _lastId) {
      final nearBottom = !_scroll.hasClients || _scroll.position.maxScrollExtent - _scroll.offset < 160;
      _lastId = last?.id;
      if (nearBottom || last?.outgoing == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) {
            unawaited(_scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 180), curve: Curves.easeOut));
          }
        });
      }
    }
    final desktop = [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux].contains(Theme.of(context).platform);
    final canSend = widget.device.ip != null;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: .15))),
          ),
          child: Row(
            children: [
              if (widget.compact)
                IconButton(
                  tooltip: t.conversations.back,
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => ref.notifier(selectedConversationProvider).select(null),
                ),
              _DeviceAvatar(device: widget.device),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.device.alias,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${widget.device.ip ?? t.conversations.chatOnlyLan} · ${widget.device.https ? t.conversations.secureTransport : t.conversations.unverified}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: t.conversations.searchMessages,
                icon: const Icon(Icons.search_rounded),
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _search = '';
                }),
              ),
              PopupMenuButton<String>(
                tooltip: t.receiveOptionsPage.title,
                onSelected: (value) async {
                  if (value == 'info') {
                    await context.push(() => DeviceDetailsPage(device: widget.device));
                    return;
                  }
                  final clear = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(t.conversations.clearHistory),
                      content: Text(t.conversations.clearConfirm),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.general.cancel)),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t.general.confirm)),
                      ],
                    ),
                  );
                  if (clear == true && mounted) ref.notifier(conversationProvider).clearPeer(peerId);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'info', child: Text(t.receiveHistoryPage.entryActions.info)),
                  PopupMenuItem(value: 'clear', enabled: !entries.any((e) => e.inFlight), child: Text(t.conversations.clearHistory)),
                ],
              ),
            ],
          ),
        ),
        if (_searching)
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(hintText: t.conversations.searchMessages, prefixIcon: const Icon(Icons.search)),
            ),
          ),
        if (!settings.saveToHistory || saveError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: .4),
            child: Text(
              saveError != null ? t.conversations.saveError : t.conversations.historyDisabled,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_search.isEmpty ? t.conversations.emptyHint : t.conversations.noResults, textAlign: TextAlign.center),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final entry = visible[index];
                    return _MessageBubble(
                      key: ValueKey(entry.id),
                      entry: entry,
                      progress: transfer.getProgress(sessionId: entry.sessionId, fileId: entry.fileId),
                      onRetry: () => _retry(entry),
                      onCancel: entry.outgoing ? () => ref.notifier(conversationOutboxProvider).cancelJob(entry.sessionId) : null,
                    );
                  },
                ),
        ),
        if (jobs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
                const SizedBox(width: 9),
                Expanded(child: Text('${t.conversations.queueHint} · ${jobs.length}', style: Theme.of(context).textTheme.labelSmall)),
              ],
            ),
          ),
        if (attachments.isNotEmpty)
          SizedBox(
            height: 50,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: attachments.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => InputChip(
                avatar: Icon(_fileIcon(attachments[index].fileType), size: 17),
                label: SizedBox(width: 150, child: Text(attachments[index].name, overflow: TextOverflow.ellipsis)),
                deleteButtonTooltipMessage: t.conversations.removeAttachment,
                onDeleted: () => ref.notifier(conversationAttachmentsProvider).remove(peerId, index),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, widget.compact ? 10 : 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: .15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PopupMenuButton<FilePickerOption>(
                  enabled: canSend,
                  tooltip: t.conversations.attach,
                  icon: const Icon(Icons.add_rounded),
                  onSelected: _attach,
                  itemBuilder: (_) => [
                    for (final option in [FilePickerOption.file, FilePickerOption.folder, FilePickerOption.clipboard])
                      PopupMenuItem(
                        value: option,
                        child: Row(children: [Icon(option.icon, size: 20), const SizedBox(width: 12), Text(option.label)]),
                      ),
                  ],
                ),
                Expanded(
                  child: Focus(
                    onKeyEvent: (_, event) {
                      if (desktop &&
                          event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed &&
                          _text.value.composing.isCollapsed) {
                        _send();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _text,
                      focusNode: _inputFocus,
                      enabled: canSend,
                      minLines: 1,
                      maxLines: 5,
                      onChanged: (value) => ref.notifier(conversationDraftsProvider).set(peerId, value),
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: t.conversations.compose,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: t.conversations.send,
                  onPressed: canSend && (_text.text.trim().isNotEmpty || attachments.isNotEmpty) ? _send : null,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ),
        ),
        if (desktop)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(t.conversations.keyboardHint, style: Theme.of(context).textTheme.labelSmall),
          ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ConversationEntry entry;
  final double progress;
  final VoidCallback onRetry;
  final VoidCallback? onCancel;

  const _MessageBubble({required this.entry, required this.progress, required this.onRetry, required this.onCancel, super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = entry.outgoing ? colors.primaryContainer.withValues(alpha: .65) : colors.surfaceContainerLow;
    final uri = entry.text == null ? null : Uri.tryParse(entry.text!.trim());
    final isLink = uri != null && ['http', 'https'].contains(uri.scheme) && uri.host.isNotEmpty && !entry.text!.trim().contains(RegExp(r'\s'));
    final status = switch (entry.delivery) {
      ConversationDelivery.waiting => t.conversations.waiting,
      ConversationDelivery.sending => t.conversations.sending,
      ConversationDelivery.delivered => entry.outgoing ? t.conversations.delivered : t.conversations.received,
      ConversationDelivery.failed => t.conversations.failed,
      ConversationDelivery.declined => t.conversations.declined,
      ConversationDelivery.cancelled => t.conversations.cancelled,
      ConversationDelivery.interrupted => t.conversations.interrupted,
    };
    return Align(
      alignment: entry.outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width < 600 ? 320 : 560),
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.fromLTRB(15, 12, 12, 8),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.text != null)
              SelectableText(entry.text!, style: const TextStyle(fontSize: 15, height: 1.5))
            else ...[
              if (entry.fileType == FileType.image &&
                  entry.path != null &&
                  !entry.path!.startsWith('content://') &&
                  entry.delivery == ConversationDelivery.delivered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(entry.path!),
                      width: 280,
                      height: 180,
                      fit: BoxFit.cover,
                      cacheWidth: 560,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              InkWell(
                onTap: entry.path == null ? null : () => openFile(context, entry.fileType, entry.path!),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: colors.surface.withValues(alpha: .65), borderRadius: BorderRadius.circular(11)),
                      child: Icon(_fileIcon(entry.fileType), size: 26, color: colors.primary),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.fileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            entry.savedToGallery ? t.conversations.savedToGallery : entry.fileSize.asReadableFileSize,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (entry.delivery == ConversationDelivery.sending)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 5),
                  child: LinearProgressIndicator(value: progress > 0 ? progress.clamp(0, 1) : null, borderRadius: BorderRadius.circular(3)),
                ),
            ],
            if (entry.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  entry.error!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.error),
                ),
              ),
            const SizedBox(height: 7),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 7,
              children: [
                Text('${_time(entry.timestamp)} · $status', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
                if (entry.text != null)
                  IconButton(
                    tooltip: t.general.copy,
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: entry.text!));
                      if (context.mounted) context.showSnackBar(t.general.copiedToClipboard);
                    },
                    icon: const Icon(Icons.copy_outlined),
                  ),
                if (isLink)
                  IconButton(
                    tooltip: t.conversations.openLink,
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new),
                  ),
                if (entry.outgoing && !entry.inFlight && entry.delivery != ConversationDelivery.delivered)
                  IconButton(
                    tooltip: t.conversations.retry,
                    visualDensity: VisualDensity.compact,
                    iconSize: 17,
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                if (entry.inFlight && onCancel != null)
                  IconButton(
                    tooltip: t.general.cancel,
                    visualDensity: VisualDensity.compact,
                    iconSize: 17,
                    onPressed: onCancel,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceAvatar extends StatelessWidget {
  final Device device;
  const _DeviceAvatar({required this.device});

  @override
  Widget build(BuildContext context) => CircleAvatar(
    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    child: Icon(
      switch (device.deviceType) {
        DeviceType.mobile => Icons.smartphone_rounded,
        DeviceType.desktop => Icons.laptop_mac_rounded,
        _ => Icons.devices_other_rounded,
      },
      color: Theme.of(context).colorScheme.onPrimaryContainer,
      size: 21,
    ),
  );
}

IconData _fileIcon(FileType type) => switch (type) {
  FileType.image => Icons.image_outlined,
  FileType.video => Icons.movie_outlined,
  FileType.text => Icons.notes_rounded,
  FileType.pdf => Icons.picture_as_pdf_outlined,
  _ => Icons.insert_drive_file_outlined,
};

String _time(DateTime value) {
  final local = value.toLocal();
  final today = DateTime.now();
  if (local.year == today.year && local.month == today.month && local.day == today.day) {
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  return '${local.month}/${local.day}';
}
