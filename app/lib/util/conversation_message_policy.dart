import 'package:localsend_isolates/model/device.dart';

bool canReceiveLiveConversationText({required Device? selected, required String? verifiedFingerprint, required bool conversationVisible}) {
  return conversationVisible && selected?.https == true && verifiedFingerprint != null && selected!.fingerprint == verifiedFingerprint;
}
