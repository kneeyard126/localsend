import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/native/cross_file_converters.dart';
import 'package:localsend_app/util/native/file_picker.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Reuse the platform pickers with a separate selection container. Picking
/// attachments for a chat must never clear or steal the normal Send selection.
Future<List<CrossFile>> pickConversationAttachments(BuildContext context, FilePickerOption option) async {
  final deviceInfo = context.read(deviceInfoProvider);
  final selection = RefenaContainer(overrides: [deviceInfoProvider.overrideWithBuilder((_) => deviceInfo)]);
  try {
    await selection.global.dispatchAsync(PickFileAction(option: option, context: context));
    return [...selection.read(selectedSendingFilesProvider)];
  } finally {
    selection.disposeContainer();
  }
}

Future<List<CrossFile>> collectConversationDrop(List<XFile> files) async {
  final selection = RefenaContainer();
  try {
    for (final file in files) {
      if (await Directory(file.path).exists()) {
        await selection.redux(selectedSendingFilesProvider).dispatchAsync(AddDirectoryAction(file.path));
      } else {
        await selection.redux(selectedSendingFilesProvider).dispatchAsync(AddFilesAction(files: [file], converter: CrossFileConverters.convertXFile));
      }
    }
    return [...selection.read(selectedSendingFilesProvider)];
  } finally {
    selection.disposeContainer();
  }
}
