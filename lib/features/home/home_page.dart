import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/app_user.dart';
import '../../core/models/conversation_summary.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/user_service.dart';

String _initials(String name) {
  final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

Widget _brandAvatar({Widget? child, double radius = 24}) => CircleAvatar(
  radius: radius,
  backgroundColor: AppColors.brand,
  child: child,
);

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet({
    required this.currentUid,
    required this.userService,
    required this.chatService,
  });

  final String currentUid;
  final UserService userService;
  final ChatService chatService;

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _nameController = TextEditingController();
  final Set<String> _selectedUserIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final groupName = _nameController.text.trim();
    if (groupName.isEmpty || _selectedUserIds.isEmpty) return;

    final members = [widget.currentUid, ..._selectedUserIds];
    final roomId = await widget.chatService.createGroup(
      name: groupName,
      memberUids: members,
      adminUid: widget.currentUid,
    );

    if (!mounted) return;
    Navigator.pop(context);
    if (!mounted) return;
    Navigator.pushNamed(
      context,
      AppRoutes.chat,
      arguments: {
        'contactId': roomId,
        'contactName': groupName,
        'isGroup': true,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.brandBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _nameController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 14,
                    ),
                    cursorColor: AppColors.brand,
                    decoration: InputDecoration(
                      labelText: 'Group name',
                      labelStyle: const TextStyle(
                        color: AppColors.brandMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                      floatingLabelStyle: const TextStyle(
                        color: AppColors.brandMuted,
                      ),
                      filled: true,
                      fillColor: AppColors.brandLight,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.brandBorder,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.brand,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select members',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<List<AppUser>>(
                    stream: widget.userService.streamAllUsersExcept(
                      widget.currentUid,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.brand,
                          ),
                        );
                      }
                      final users = snapshot.data ?? [];
                      if (users.isEmpty) {
                        return const Center(
                          child: Text(
                            'No users available.',
                            style: TextStyle(color: AppColors.brandMuted),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: AppColors.brandBorder,
                        ),
                        itemBuilder: (_, index) {
                          final user = users[index];
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
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedUserIds.add(user.uid);
                                } else {
                                  _selectedUserIds.remove(user.uid);
                                }
                              });
                            },
                            title: Text(
                              user.username,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 14,
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
                            secondary: _brandAvatar(
                              child: Text(
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed:
                          _nameController.text.trim().isEmpty ||
                              _selectedUserIds.isEmpty
                          ? null
                          : _createGroup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandSoft,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.brandBorder,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: const Text('Create Group'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupChatTileData {
  const _GroupChatTileData({
    required this.roomId,
    required this.name,
    required this.summary,
  });
  final String roomId;
  final String name;
  final ConversationSummary summary;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authService = AuthService.instance;
  final _userService = UserService.instance;
  final _chatService = ChatService.instance;

  String get _currentUid => _authService.currentAuthUser?.uid ?? '';

  Widget _buildUserAvatar(AppUser user) {
    if (user.hasProfileImage) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: MemoryImage(base64Decode(user.profileImageBase64)),
      );
    }
    return _brandAvatar(
      child: Text(
        _initials(user.username),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _openCamera(BuildContext context) async {
    if (_currentUid.isEmpty) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null || !context.mounted) return;

    final receiver = await _pickReceiverForImage(context);
    if (receiver == null || !context.mounted) return;

    try {
      await _chatService.sendImageMessage(
        senderUid: _currentUid,
        receiverUid: receiver.uid,
        imageFile: File(picked.path),
      );
      if (!context.mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.chat,
        arguments: {
          'contactId': receiver.uid,
          'contactName': receiver.username,
        },
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to send captured image.')),
      );
    }
  }

  Future<void> _openCreateGroup(BuildContext context) async {
    if (_currentUid.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateGroupSheet(
        currentUid: _currentUid,
        userService: _userService,
        chatService: _chatService,
      ),
    );
  }

  Future<AppUser?> _pickReceiverForImage(BuildContext context) {
    return showModalBottomSheet<AppUser>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: StreamBuilder<List<AppUser>>(
          stream: _userService.streamAllUsersExcept(_currentUid),
          builder: (_, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 220,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                ),
              );
            }
            final users = snapshot.data ?? [];
            if (users.isEmpty) {
              return const SizedBox(
                height: 220,
                child: Center(
                  child: Text(
                    'No users available.',
                    style: TextStyle(color: AppColors.brandMuted),
                  ),
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.brandBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Send captured image to',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: users.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.brandBorder),
                    itemBuilder: (_, index) {
                      final user = users[index];
                      return ListTile(
                        leading: _brandAvatar(
                          child: Text(
                            _initials(user.username),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
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
                        onTap: () => Navigator.pop(sheetContext, user),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatTimestamp(BuildContext context, DateTime? value) {
    if (value == null) return '';
    final now = DateTime.now();
    final isToday =
        value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
    if (isToday) return TimeOfDay.fromDateTime(value).format(context);
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
  }

  Icon _tickIcon(bool isMine, bool read, bool delivered) {
    if (!isMine)
      return const Icon(Icons.done, size: 16, color: Colors.transparent);
    if (read)
      return const Icon(Icons.done_all, size: 16, color: AppColors.brand);
    if (delivered)
      return const Icon(Icons.done_all, size: 16, color: AppColors.textHint);
    return const Icon(Icons.done, size: 16, color: AppColors.textHint);
  }

  Icon _buildTickIcon(ConversationSummary s, AppUser user) => _tickIcon(
    s.lastMessageSenderId == _currentUid && s.lastMessageReceiverId == user.uid,
    s.lastMessageRead,
    s.lastMessageDelivered,
  );

  Icon _buildGroupTickIcon(ConversationSummary s) => _tickIcon(
    s.lastMessageSenderId == _currentUid,
    s.lastMessageRead,
    s.lastMessageDelivered,
  );

  String _lastMessagePreview(ConversationSummary? s, AppUser user) {
    if (s == null || s.lastMessageText.isEmpty) return 'Tap to start chatting';
    return s.lastMessageText;
  }

  List<AppUser> _orderUsers(
    List<AppUser> users,
    Map<String, ConversationSummary> byOtherUser,
  ) {
    final ordered = [...users];
    ordered.sort((a, b) {
      final at = byOtherUser[a.uid]?.lastMessageAt;
      final bt = byOtherUser[b.uid]?.lastMessageAt;
      if (at == null && bt == null)
        return a.username.toLowerCase().compareTo(b.username.toLowerCase());
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return ordered;
  }

  List<_GroupChatTileData> _orderGroups(List<ConversationSummary> summaries) {
    final groups = summaries
        .where((s) => s.isGroup)
        .map(
          (s) => _GroupChatTileData(
            roomId: s.roomId,
            name: s.groupName.isNotEmpty ? s.groupName : 'Group',
            summary: s,
          ),
        )
        .toList();
    groups.sort((a, b) {
      final at = a.summary.lastMessageAt;
      final bt = b.summary.lastMessageAt;
      if (at == null && bt == null)
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return groups;
  }

  Widget _chatCard({
    required Widget avatar,
    required String name,
    required Widget subtitle,
    required String time,
    required int unreadCount,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: avatar,
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.textDark,
            fontSize: 15,
          ),
        ),
        subtitle: subtitle,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.brandMuted,
        letterSpacing: 0.7,
      ),
    ),
  );

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
        leadingWidth: 108,
        leading: Row(
          children: [
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.brand,
              ),
              onPressed: () async => _openCamera(context),
            ),
            IconButton(
              icon: const Icon(
                Icons.group_add_outlined,
                color: AppColors.brand,
              ),
              onPressed: () async => _openCreateGroup(context),
            ),
          ],
        ),
        title: StreamBuilder<AppUser?>(
          stream: _userService.streamUserByUid(_currentUid),
          builder: (_, snapshot) {
            final username = snapshot.data?.username;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Chats',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brand,
                  ),
                ),
                if (username != null && username.isNotEmpty)
                  Text(
                    'Signed in as $username',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.brandMuted,
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.brand),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
          ),
        ],
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: _userService.streamAllUsersExcept(_currentUid),
        builder: (_, usersSnapshot) {
          if (usersSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            );
          }
          if (usersSnapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load users.',
                style: TextStyle(color: AppColors.brandMuted),
              ),
            );
          }

          final users = usersSnapshot.data ?? [];

          return StreamBuilder<List<ConversationSummary>>(
            stream: _chatService.streamConversations(_currentUid),
            builder: (_, convSnapshot) {
              final convList = convSnapshot.data ?? [];
              final byOtherUser = <String, ConversationSummary>{};
              for (final s in convList) {
                if (s.isGroup) continue;
                final other = s.otherParticipant(_currentUid);
                if (other != null) byOtherUser[other] = s;
              }

              final orderedUsers = _orderUsers(users, byOtherUser);
              final orderedGroups = _orderGroups(convList);

              if (users.isEmpty && orderedGroups.isEmpty) {
                return const Center(
                  child: Text(
                    'No chats found.',
                    style: TextStyle(color: AppColors.brandMuted),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (orderedGroups.isNotEmpty) ...[
                    _sectionLabel('Groups'),
                    ...orderedGroups.map((group) {
                      final s = group.summary;
                      final unread = s.unreadFor(_currentUid);
                      return _chatCard(
                        avatar: _brandAvatar(
                          child: const Icon(
                            Icons.group,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        name: group.name,
                        subtitle: Row(
                          children: [
                            if (s.lastMessageSenderId == _currentUid) ...[
                              _buildGroupTickIcon(s),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                s.lastMessageText.isEmpty
                                    ? 'Tap to start chatting'
                                    : s.lastMessageText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: unread > 0
                                      ? AppColors.brandSoft
                                      : AppColors.textHint,
                                  fontWeight: unread > 0
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                        time: _formatTimestamp(context, s.lastMessageAt),
                        unreadCount: unread,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.chat,
                          arguments: {
                            'contactId': group.roomId,
                            'contactName': group.name,
                            'isGroup': true,
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    _sectionLabel('Contacts'),
                  ],
                  ...orderedUsers.map((user) {
                    final s = byOtherUser[user.uid];
                    final unread = s?.unreadFor(_currentUid) ?? 0;
                    return _chatCard(
                      avatar: _buildUserAvatar(user),
                      name: user.username,
                      subtitle: Row(
                        children: [
                          if (s != null) ...[
                            _buildTickIcon(s, user),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              _lastMessagePreview(s, user),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: unread > 0
                                    ? AppColors.brandSoft
                                    : AppColors.textHint,
                                fontWeight: unread > 0
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      time: _formatTimestamp(context, s?.lastMessageAt),
                      unreadCount: unread,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.chat,
                        arguments: {
                          'contactId': user.uid,
                          'contactName': user.username,
                        },
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
