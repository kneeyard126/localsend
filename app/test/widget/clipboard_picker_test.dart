import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/native/file_picker.dart';
import 'package:localsend_isolates/model/file_type.dart';
import 'package:localsend_isolates/rust/api/model.dart' as rust;
import 'package:localsend_isolates/rust/frb_generated.dart';
import 'package:refena_flutter/refena_flutter.dart';

class _RustLibApi extends Fake implements RustLibApi {
  @override
  Future<rust.FileMetadata?> crateApiMetadataReadFileMetadata({required String path}) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  late File file;
  late List<String> files;
  late String? text;
  late Uint8List? image;
  late List<String> calls;
  late bool filesUnsupported;

  setUpAll(() => RustLib.initMock(api: _RustLibApi()));

  setUp(() {
    directory = Directory.systemTemp.createTempSync('localsend-clipboard-test-');
    file = File('${directory.path}/example.txt')..writeAsStringSync('file contents');
    files = [];
    text = null;
    image = null;
    calls = [];
    filesUnsupported = false;
    messenger.setMockMethodCallHandler(const MethodChannel('pasteboard'), (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'files':
          if (filesUnsupported) throw MissingPluginException();
          return files;
        case 'image':
          return image;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        calls.add('text');
        return text == null ? null : {'text': text};
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(const MethodChannel('pasteboard'), null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    directory.deleteSync(recursive: true);
  });

  Future<List<CrossFile>> paste(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      RefenaScope(
        child: MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      ),
    );
    await tester.runAsync(() => context.global.dispatchAsync(PickFileAction(option: FilePickerOption.clipboard, context: context)));
    return context.read(selectedSendingFilesProvider);
  }

  testWidgets('file-manager copies take priority over their plain-text representation', (tester) async {
    files = [file.path];
    text = file.path;
    final selected = await paste(tester);
    expect(selected.single.path, file.path);
    expect(selected.single.bytes, isNull);
    expect(selected.single.size, file.lengthSync());
    expect(calls, ['files']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('copied files take priority over image thumbnails', (tester) async {
    files = [file.path];
    image = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
    final selected = await paste(tester);
    expect(selected.single.path, file.path);
    expect(calls, ['files']);
  });

  testWidgets('plain text still works when the clipboard contains no files', (tester) async {
    text = 'Hello, 你好';
    final selected = await paste(tester);
    expect(selected.single.fileType, FileType.text);
    expect(selected.single.path, isNull);
  });

  testWidgets('platforms without clipboard file support can still paste text', (tester) async {
    filesUnsupported = true;
    text = 'Hello';
    final selected = await paste(tester);
    expect(selected.single.fileType, FileType.text);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clipboard images remain supported', (tester) async {
    image = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
    final selected = await paste(tester);
    expect(selected.single.fileType, FileType.image);
    expect(selected.single.bytes, image);
  });

  testWidgets('an empty clipboard adds nothing', (tester) async {
    expect(await paste(tester), isEmpty);
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
