import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/chat_files_browse.dart';
import '../widgets/chat/chat_files_browser.dart';

/// 채팅방 메뉴 '주고받은 파일' — 예전 70% 높이 시트 대신 전체 화면.
/// 사진 바둑판을 넓게 보고 오래 내려 보는 화면이라 시트로는 좁았다.
class ChatFilesScreen extends StatelessWidget {
  const ChatFilesScreen({
    super.key,
    required this.roomId,
    required this.onOpen,
    this.initialKind = ChatFilesKind.photo,
  });

  final int roomId;
  final ChatFilesKind initialKind;

  /// 여는 방식은 채팅방 말풍선과 같게 — 채팅방 화면이 넘겨준다
  final void Function(ChatMessage message) onOpen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundCanvas,
      appBar: AppBar(
        title: Text('주고받은 파일', style: AppTypography.appBarTitle),
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: ChatFilesBrowser(roomId: roomId, onOpen: onOpen, initialKind: initialKind),
      ),
    );
  }
}
