import 'package:localsend_app/util/conversation_message_policy.dart';
import 'package:test/test.dart';

import '../../fixtures/conversation_fixtures.dart';

void main() {
  test('only the visible selected TLS peer can deliver text without a modal', () {
    expect(canReceiveLiveConversationText(selected: chatPeer('peer'), verifiedFingerprint: 'peer', conversationVisible: true), isTrue);
    expect(canReceiveLiveConversationText(selected: chatPeer('peer'), verifiedFingerprint: null, conversationVisible: true), isFalse);
    expect(canReceiveLiveConversationText(selected: chatPeer('peer'), verifiedFingerprint: 'other', conversationVisible: true), isFalse);
    expect(canReceiveLiveConversationText(selected: chatPeer('peer'), verifiedFingerprint: 'peer', conversationVisible: false), isFalse);
    expect(canReceiveLiveConversationText(selected: chatPeer('peer', https: false), verifiedFingerprint: 'peer', conversationVisible: true), isFalse);
    expect(canReceiveLiveConversationText(selected: null, verifiedFingerprint: 'peer', conversationVisible: true), isFalse);
  });
}
