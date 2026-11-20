import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/conversation_entry.dart';
import 'package:localsend_app/model/state/settings_state.dart';
import 'package:localsend_app/pages/tabs/conversations_tab.dart';
import 'package:localsend_app/provider/conversation_outbox_provider.dart';
import 'package:localsend_app/provider/conversation_provider.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../fixtures/conversation_fixtures.dart';

class _Settings extends Fake implements SettingsState {
  @override
  bool get saveToHistory => true;
}

class _SettingsService extends SettingsService {
  _SettingsService(super.persistence);

  @override
  SettingsState init() => _Settings();
}

void main() {
  late RefenaContainer ref;
  late MemoryChatPersistence memory;
  late List<ConversationJob> sent;

  setUp(() {
    memory = MemoryChatPersistence();
    sent = [];
    ref = RefenaContainer(
      overrides: [
        persistenceProvider.overrideWithValue(memory),
        settingsProvider.overrideWithNotifier((_) => _SettingsService(memory)),
        conversationOutboxProvider.overrideWithNotifier(
          (ref) => ConversationOutboxNotifier(
            history: ref.notifier(conversationProvider),
            send: (job) async {
              sent.add(job);
              ref.notifier(conversationProvider).finishSession(job.id, outgoing: true, delivery: ConversationDelivery.delivered);
            },
            cancel: (_) {},
          ),
        ),
      ],
    );
  });
  tearDown(() {
    ref.disposeContainer();
  });

  Future<void> pumpChat(WidgetTester tester, {Size size = const Size(900, 650), double scale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RefenaScope.withContainer(
        container: ref,
        ownsContainer: false,
        child: MaterialApp(
          theme: ThemeData(
            platform: TargetPlatform.macOS,
            inputDecorationTheme: const InputDecorationTheme(fillColor: Colors.grey),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: ConversationPane(device: chatPeer('peer'), compact: size.width < 760),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('desktop Enter sends text and records the resulting message without a modal', (tester) async {
    await pumpChat(tester);
    await tester.enterText(find.byType(TextField), '你好, LocalSend');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(sent.length, 1);
    expect(ref.read(conversationProvider).single.text, '你好, LocalSend');
    expect(find.text('你好, LocalSend'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shift+Enter and an IME composition do not submit the draft', (tester) async {
    await pumpChat(tester);
    await tester.enterText(find.byType(TextField), 'draft');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    final controller = tester.widget<TextField>(find.byType(TextField)).controller!;
    controller.value = const TextEditingValue(text: 'pinyin', selection: TextSelection.collapsed(offset: 6), composing: TextRange(start: 0, end: 6));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('text and attachments are separate queued transfers so text remains a message', (tester) async {
    ref.notifier(conversationAttachmentsProvider).add('peer', [chatFile('attachment.txt')]);
    await pumpChat(tester);
    await tester.enterText(find.byType(TextField), 'Message with file');
    await tester.tap(find.byTooltip(t.conversations.send));
    await tester.pumpAndSettle();
    expect(sent.length, 2);
    expect(sent.first.files.single.name, startsWith('message-'));
    expect(sent.last.files.single.name, 'attachment.txt');
    expect(ref.read(conversationAttachmentsProvider)['peer'], isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone layout with large text has no overflow', (tester) async {
    ref.notifier(conversationProvider).upsert(chatEntry('received', outgoing: false, text: 'A message that wraps across several lines. ' * 8));
    await pumpChat(tester, size: const Size(375, 700), scale: 2);
    expect(find.byTooltip(t.conversations.back), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a saved draft is restored when opening a conversation', (tester) async {
    ref.notifier(conversationDraftsProvider).set('peer', 'Unsent draft');
    await pumpChat(tester);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Unsent draft');
    expect(sent, isEmpty);
  });

  testWidgets('a global paste updates the focused composer and sends the new text', (tester) async {
    await pumpChat(tester);
    await tester.enterText(find.byType(TextField), 'Before paste');
    ref.notifier(conversationDraftsProvider).set('peer', 'Before paste：你好 👋');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Before paste：你好 👋');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(ref.read(conversationProvider).single.text, 'Before paste：你好 👋');
    expect(tester.takeException(), isNull);
  });
}
