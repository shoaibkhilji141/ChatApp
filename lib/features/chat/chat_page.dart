import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/app_user.dart';
import '../../core/models/chat_message.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/user_service.dart';

String _initials(String name) {
  final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.contactId,
    required this.contactName,
    this.isGroup = false,
  });

  final String contactId;
  final String contactName;
  final bool isGroup;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final _chatService = ChatService.instance;
  final _authService = AuthService.instance;
  final _userService = UserService.instance;
  bool _isSyncingReceipts = false;

  String get _currentUid => _authService.currentAuthUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncReceipts());
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUid.isEmpty || widget.contactId.isEmpty) return;
    _messageController.clear();
    if (widget.isGroup) {
      await _chatService.sendGroupMessage(
        senderUid: _currentUid,
        roomId: widget.contactId,
        text: text,
      );
    } else {
      await _chatService.sendMessage(
        senderUid: _currentUid,
        receiverUid: widget.contactId,
        text: text,
      );
    }
  }

  Future<void> _syncReceipts() async {
    if (_isSyncingReceipts || _currentUid.isEmpty || widget.contactId.isEmpty)
      return;
    _isSyncingReceipts = true;
    try {
      if (widget.isGroup) {
        await _chatService.markGroupIncomingAsDelivered(
          currentUid: _currentUid,
          roomId: widget.contactId,
        );
        await _chatService.markGroupConversationAsRead(
          currentUid: _currentUid,
          roomId: widget.contactId,
        );
      } else {
        await _chatService.markIncomingAsDelivered(
          currentUid: _currentUid,
          otherUid: widget.contactId,
        );
        await _chatService.markConversationAsRead(
          currentUid: _currentUid,
          otherUid: widget.contactId,
        );
      }
    } finally {
      _isSyncingReceipts = false;
    }
  }

  Future<void> _sendPickedImage(File imageFile) async {
    if (widget.isGroup) {
      await _chatService.sendGroupImage(
        senderUid: _currentUid,
        roomId: widget.contactId,
        imageFile: imageFile,
      );
    } else {
      await _chatService.sendImageMessage(
        senderUid: _currentUid,
        receiverUid: widget.contactId,
        imageFile: imageFile,
      );
    }
  }

  Future<void> _pickAndPreviewImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;

    final imageFile = File(picked.path);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (previewContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.brandBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(imageFile, fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(previewContext),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brand,
                        side: const BorderSide(
                          color: AppColors.brandBorder,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(previewContext);
                        try {
                          await _sendPickedImage(imageFile);
                        } catch (_) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Unable to send image.'),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandSoft,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Send'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGroupMembers() async {
    final roomData = await _chatService.fetchRoomData(widget.contactId);
    if (!mounted || roomData == null) return;

    final participantIds = (roomData['participants'] as List<dynamic>? ?? [])
        .map((v) => v.toString())
        .where((v) => v.isNotEmpty)
        .toList();
    final adminIds = (roomData['admins'] as List<dynamic>? ?? [])
        .map((v) => v.toString())
        .where((v) => v.isNotEmpty)
        .toList();
    final groupName = (roomData['groupName'] ?? widget.contactName) as String;

    if (participantIds.isEmpty || !mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
      builder: (_) => _GroupMembersSheet(
        groupName: groupName,
        roomId: widget.contactId,
        currentUid: _currentUid,
        participantIds: participantIds,
        adminIds: adminIds,
        userService: _userService,
        chatService: _chatService,
      ),
    );
  }

  Future<void> _showAddMembersSheet() async {
    final roomData = await _chatService.fetchRoomData(widget.contactId);
    if (!mounted || roomData == null) return;

    final participantIds = (roomData['participants'] as List<dynamic>? ?? [])
        .map((v) => v.toString())
        .where((v) => v.isNotEmpty)
        .toSet();
    final adminIds = (roomData['admins'] as List<dynamic>? ?? [])
        .map((v) => v.toString())
        .where((v) => v.isNotEmpty)
        .toSet();

    if (!adminIds.contains(_currentUid)) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddGroupMembersSheet(
        roomId: widget.contactId,
        currentUid: _currentUid,
        existingParticipantIds: participantIds,
        userService: _userService,
        chatService: _chatService,
      ),
    );
  }

  Widget _buildStatusTick(ChatMessage message, bool isMe) {
    if (!isMe) return const SizedBox.shrink();
    if (widget.isGroup) {
      if (message.readBy.length > 1)
        return const Icon(
          Icons.done_all,
          size: 15,
          color: AppColors.receiptRead,
        );
      if (message.deliveredTo.length > 1)
        return Icon(Icons.done_all, size: 15, color: AppColors.whiteMedium);
      return Icon(Icons.done, size: 15, color: AppColors.whiteMedium);
    }
    switch (message.receiptStatusFor(widget.contactId)) {
      case MessageReceiptStatus.read:
        return const Icon(
          Icons.done_all,
          size: 15,
          color: AppColors.receiptRead,
        );
      case MessageReceiptStatus.delivered:
        return Icon(Icons.done_all, size: 15, color: AppColors.whiteMedium);
      case MessageReceiptStatus.sent:
        return Icon(Icons.done, size: 15, color: AppColors.whiteMedium);
    }
  }

  Widget _miniAvatar(AppUser? user) {
    final hasImage = user?.hasProfileImage ?? false;
    return CircleAvatar(
      radius: 9,
      backgroundColor: AppColors.brand,
      backgroundImage: hasImage
          ? MemoryImage(base64Decode(user!.profileImageBase64))
          : null,
      child: hasImage
          ? null
          : const Icon(Icons.person, size: 11, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.brandBorder),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.brand),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: widget.isGroup
            ? InkWell(
                onTap: _showGroupMembers,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.brand,
                      child: const Icon(
                        Icons.group,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.contactName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
              )
            : Text(
                widget.contactName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brand,
                ),
              ),
        actions: [
          if (widget.isGroup)
            FutureBuilder<Map<String, dynamic>?>(
              future: _chatService.fetchRoomData(widget.contactId),
              builder: (_, snapshot) {
                final admins =
                    (snapshot.data?['admins'] as List<dynamic>? ?? [])
                        .map((v) => v.toString())
                        .toSet();
                if (!admins.contains(_currentUid))
                  return const SizedBox.shrink();
                return IconButton(
                  tooltip: 'Add members',
                  icon: const Icon(
                    Icons.person_add_alt_1,
                    color: AppColors.brand,
                  ),
                  onPressed: _showAddMembersSheet,
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.white,
              child: StreamBuilder<AppUser?>(
                stream: _userService.streamUserByUid(_currentUid),
                builder: (_, currentUserSnap) => StreamBuilder<AppUser?>(
                  stream: _userService.streamUserByUid(widget.contactId),
                  builder: (_, contactUserSnap) {
                    final currentUser = currentUserSnap.data;
                    final contactUser = contactUserSnap.data;

                    return StreamBuilder<List<ChatMessage>>(
                      stream: widget.isGroup
                          ? _chatService.streamGroupMessages(widget.contactId)
                          : _chatService.streamMessages(
                              currentUid: _currentUid,
                              otherUid: widget.contactId,
                            ),
                      builder: (_, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.brand,
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return const Center(
                            child: Text(
                              'Unable to load messages.',
                              style: TextStyle(color: AppColors.brandMuted),
                            ),
                          );
                        }

                        final messages = snapshot.data ?? const <ChatMessage>[];
                        if (messages.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _syncReceipts(),
                          );
                        }
                        if (messages.isEmpty) {
                          return const Center(
                            child: Text(
                              'No messages yet. Start chatting!',
                              style: TextStyle(color: AppColors.brandMuted),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final msg = messages[index];
                            final isMe = msg.senderId == _currentUid;

                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 280,
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: isMe
                                          ? [
                                              Text(
                                                'You',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textHint,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              _miniAvatar(currentUser),
                                            ]
                                          : [
                                              widget.isGroup
                                                  ? StreamBuilder<AppUser?>(
                                                      stream: _userService
                                                          .streamUserByUid(
                                                            msg.senderId,
                                                          ),
                                                      builder: (_, s) =>
                                                          _miniAvatar(s.data),
                                                    )
                                                  : _miniAvatar(contactUser),
                                              const SizedBox(width: 5),
                                              widget.isGroup
                                                  ? StreamBuilder<AppUser?>(
                                                      stream: _userService
                                                          .streamUserByUid(
                                                            msg.senderId,
                                                          ),
                                                      builder: (_, s) => Text(
                                                        s.data?.username ??
                                                            msg.senderId,
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: AppColors
                                                              .textHint,
                                                        ),
                                                      ),
                                                    )
                                                  : Text(
                                                      widget.contactName,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            AppColors.textHint,
                                                      ),
                                                    ),
                                            ],
                                    ),
                                    const SizedBox(height: 4),

                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? AppColors.brand
                                            : AppColors.brandLight,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft: Radius.circular(
                                            isMe ? 16 : 4,
                                          ),
                                          bottomRight: Radius.circular(
                                            isMe ? 4 : 16,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          if (!msg.isImage)
                                            Text(
                                              msg.text,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isMe
                                                    ? Colors.white
                                                    : AppColors.textDark,
                                                height: 1.4,
                                              ),
                                            ),
                                          if (msg.isImage)
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child:
                                                  msg.imageUrl.startsWith(
                                                    'http',
                                                  )
                                                  ? Image.network(
                                                      msg.imageUrl,
                                                      width: 220,
                                                      height: 220,
                                                      fit: BoxFit.cover,
                                                    )
                                                  : Image.memory(
                                                      base64Decode(
                                                        msg.imageUrl,
                                                      ),
                                                      width: 220,
                                                      height: 220,
                                                      fit: BoxFit.cover,
                                                    ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 3),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: isMe
                                          ? [
                                              _buildStatusTick(msg, true),
                                              const SizedBox(width: 3),
                                              Text(
                                                '',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.textHint,
                                                ),
                                              ),
                                            ]
                                          : [
                                              Text(
                                                '',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.textHint,
                                                ),
                                              ),
                                            ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),

          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              color: AppColors.brand,
              child: Row(
                children: [
                  _AttachBtn(onTap: _openAttachmentOptions),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        hintText: 'Type here',
                        hintStyle: TextStyle(
                          color: AppColors.whiteLight,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: AppColors.whiteTranslucent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(21),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(21),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(21),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: AppColors.brand,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAttachmentOptions() async {
    if (_currentUid.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachOption(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _pickAndPreviewImage(ImageSource.camera);
                },
              ),
              _AttachOption(
                icon: Icons.photo_library_outlined,
                label: 'Photos',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _pickAndPreviewImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachBtn extends StatelessWidget {
  const _AttachBtn({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.whiteVeryLight,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.add, color: Colors.white, size: 22),
    ),
  );
}

class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD0D4F7)),
          ),
          child: Icon(icon, color: const Color(0xFF0000CC), size: 26),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF5555AA),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class _GroupMembersSheet extends StatefulWidget {
  const _GroupMembersSheet({
    required this.groupName,
    required this.roomId,
    required this.currentUid,
    required this.participantIds,
    required this.adminIds,
    required this.userService,
    required this.chatService,
  });
  final String groupName, roomId, currentUid;
  final List<String> participantIds, adminIds;
  final UserService userService;
  final ChatService chatService;

  @override
  State<_GroupMembersSheet> createState() => _GroupMembersSheetState();
}

class _GroupMembersSheetState extends State<_GroupMembersSheet> {
  Future<void> _kickMember(String memberId, String displayName) async {
    final shouldRemove =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Remove member',
              style: TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            content: Text(
              'Remove $displayName from this group?',
              style: const TextStyle(color: AppColors.textDark),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandMuted,
                ),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.errorRed,
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldRemove) return;
    await widget.chatService.removeGroupMember(
      roomId: widget.roomId,
      memberUid: memberId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$displayName removed from group.')));
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.adminIds.contains(widget.currentUid);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Members',
              style: TextStyle(fontSize: 12, color: AppColors.brandMuted),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.participantIds.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.brandBorder),
                itemBuilder: (_, index) {
                  final memberId = widget.participantIds[index];
                  final isMe = memberId == widget.currentUid;
                  final isAdminMember = widget.adminIds.contains(memberId);

                  return StreamBuilder<AppUser?>(
                    stream: widget.userService.streamUserByUid(memberId),
                    builder: (_, snapshot) {
                      final user = snapshot.data;
                      final displayName = user?.username ?? memberId;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.brand,
                          backgroundImage: user?.hasProfileImage == true
                              ? MemoryImage(
                                  base64Decode(user!.profileImageBase64),
                                )
                              : null,
                          child: user?.hasProfileImage == true
                              ? null
                              : Text(
                                  _initials(displayName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          isMe
                              ? 'You · ${isAdminMember ? 'Admin' : 'Member'}'
                              : '${isAdminMember ? 'Admin' : 'Member'} · ${user?.email ?? memberId}',
                          style: const TextStyle(
                            color: AppColors.brandMuted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: isAdmin && !isMe && !isAdminMember
                            ? IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: AppColors.errorRed,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _kickMember(memberId, displayName),
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddGroupMembersSheet extends StatefulWidget {
  const _AddGroupMembersSheet({
    required this.roomId,
    required this.currentUid,
    required this.existingParticipantIds,
    required this.userService,
    required this.chatService,
  });
  final String roomId, currentUid;
  final Set<String> existingParticipantIds;
  final UserService userService;
  final ChatService chatService;

  @override
  State<_AddGroupMembersSheet> createState() => _AddGroupMembersSheetState();
}

class _AddGroupMembersSheetState extends State<_AddGroupMembersSheet> {
  final Set<String> _selectedUserIds = {};

  Future<void> _addMembers() async {
    if (_selectedUserIds.isEmpty) return;
    await widget.chatService.addGroupMembers(
      roomId: widget.roomId,
      memberUids: _selectedUserIds.toList(),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Add members',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brand,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.brandMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: StreamBuilder<List<AppUser>>(
                stream: widget.userService.streamAllUsersExcept(
                  widget.currentUid,
                ),
                builder: (_, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.brand),
                    );
                  }
                  final candidates = (snapshot.data ?? [])
                      .where(
                        (u) => !widget.existingParticipantIds.contains(u.uid),
                      )
                      .toList();

                  if (candidates.isEmpty) {
                    return const Center(
                      child: Text(
                        'No users available to add.',
                        style: TextStyle(color: AppColors.brandMuted),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: candidates.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.brandBorder),
                    itemBuilder: (_, index) {
                      final user = candidates[index];
                      return CheckboxListTile(
                        value: _selectedUserIds.contains(user.uid),
                        activeColor: AppColors.brand,
                        checkColor: Colors.white,
                        side: const BorderSide(
                          color: AppColors.brandMuted,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selectedUserIds.add(user.uid);
                          } else {
                            _selectedUserIds.remove(user.uid);
                          }
                        }),
                        title: Text(
                          user.username,
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          user.email,
                          style: const TextStyle(
                            color: AppColors.brandMuted,
                            fontSize: 12,
                          ),
                        ),
                        secondary: CircleAvatar(
                          backgroundColor: AppColors.brand,
                          backgroundImage: user.hasProfileImage
                              ? MemoryImage(
                                  base64Decode(user.profileImageBase64),
                                )
                              : null,
                          child: user.hasProfileImage
                              ? null
                              : Text(
                                  _initials(user.username),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _selectedUserIds.isEmpty ? null : _addMembers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandSoft,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.brandBorder,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('Add to Group'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
