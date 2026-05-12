import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../../core/models/app_user.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/session_service.dart';
import '../../core/services/user_service.dart';

const Color _brand = Color(0xFF0000CC);
const Color _brandSoft = Color(0xFF3333DD);
const Color _brandLight = Color(0xFFF0F2FF);
const Color _brandMuted = Color(0xFF5555AA);
const Color _brandBorder = Color(0xFFD0D4F7);
const Color _textDark = Color(0xFF1A1A4D);
const Color _textHint = Color(0xFF8888CC);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _userService = UserService.instance;
  final _authService = AuthService.instance;
  final _imagePicker = ImagePicker();

  bool _isSavingPhoto = false;
  bool _isUpdatingProfile = false;

  String get _currentUid => _authService.currentAuthUser?.uid ?? '';

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    if (_currentUid.isEmpty) return;
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;

    setState(() => _isSavingPhoto = true);
    try {
      final fileBytes = await File(picked.path).readAsBytes();
      final decoded = img.decodeImage(fileBytes);
      if (decoded == null)
        throw Exception('Unable to process the selected photo.');
      final resized = decoded.width > 1024
          ? img.copyResize(decoded, width: 1024)
          : decoded;
      final profileImageBase64 = base64Encode(
        img.encodeJpg(resized, quality: 65),
      );
      await _userService.updateProfileImage(
        uid: _currentUid,
        profileImageBase64: profileImageBase64,
      );
      if (!mounted) return;
      _showMessage('Profile picture updated.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSavingPhoto = false);
    }
  }

  void _showPhotoSourcePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetTile(
              icon: Icons.photo_library_outlined,
              title: 'Choose from gallery',
              onTap: () {
                Navigator.pop(sheetContext);
                _pickProfileImage(ImageSource.gallery);
              },
            ),
            _sheetTile(
              icon: Icons.camera_alt_outlined,
              title: 'Take a photo',
              onTap: () {
                Navigator.pop(sheetContext);
                _pickProfileImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _sheetTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _brandLight,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: _brand, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: _textDark,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  String _errorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'username-already-in-use':
          return 'Username is already taken.';
        case 'weak-password':
          return 'Use a stronger password.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Current password is incorrect.';
        case 'requires-recent-login':
          return 'Please sign in again and then retry.';
      }
      if (error.message?.trim().isNotEmpty == true) return error.message!;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _saveUsername(String username) async {
    if (_currentUid.isEmpty) return;
    setState(() => _isUpdatingProfile = true);
    try {
      await _userService.updateUsername(uid: _currentUid, username: username);
      if (!mounted) return;
      _showMessage('Username updated.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(_errorMessage(e));
    } finally {
      if (mounted) setState(() => _isUpdatingProfile = false);
    }
  }

  Future<void> _saveDescription(String description) async {
    if (_currentUid.isEmpty) return;
    setState(() => _isUpdatingProfile = true);
    try {
      await _userService.updateDescription(
        uid: _currentUid,
        description: description,
      );
      if (!mounted) return;
      _showMessage('Description updated.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(_errorMessage(e));
    } finally {
      if (mounted) setState(() => _isUpdatingProfile = false);
    }
  }

  Future<void> _savePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    setState(() => _isUpdatingProfile = true);
    try {
      await _authService.updatePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (!mounted) return;
      _showMessage('Password updated.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(_errorMessage(e));
    } finally {
      if (mounted) setState(() => _isUpdatingProfile = false);
    }
  }

  InputDecoration _dialogFieldDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: _brandMuted,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
    ),
    floatingLabelStyle: const TextStyle(color: _brandMuted),
    filled: true,
    fillColor: _brandLight,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _brandBorder, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _brand, width: 1.5),
    ),
  );

  AlertDialog _styledDialog({
    required String title,
    required Widget content,
    required List<Widget> actions,
  }) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    titleTextStyle: const TextStyle(
      color: _brand,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    title: Text(title),
    content: content,
    actions: actions,
  );

  Future<void> _showEditUsernameDialog(AppUser user) async {
    var value = user.username;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _styledDialog(
        title: 'Edit Username',
        content: TextFormField(
          initialValue: user.username,
          autofocus: true,
          style: const TextStyle(color: _textDark, fontSize: 14),
          cursorColor: _brand,
          decoration: _dialogFieldDecoration('Username'),
          onChanged: (v) => value = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: _brandMuted),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, value.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandSoft,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || result == user.username) {
      if (result != null && result.isEmpty) {
        _showMessage('Username cannot be empty.');
      }
      return;
    }
    await _saveUsername(result);
  }

  Future<void> _showEditDescriptionDialog(AppUser user) async {
    var value = user.description;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _styledDialog(
        title: 'Edit Description',
        content: TextFormField(
          initialValue: user.description,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(color: _textDark, fontSize: 14),
          cursorColor: _brand,
          decoration: _dialogFieldDecoration('Description'),
          onChanged: (v) => value = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: _brandMuted),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, value),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandSoft,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await _saveDescription(result);
  }

  Future<void> _showEditPasswordDialog() async {
    var currentPw = '', newPw = '', confirmPw = '';
    final result = await showDialog<(String, String, String)>(
      context: context,
      builder: (ctx) => _styledDialog(
        title: 'Edit Password',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              obscureText: true,
              style: const TextStyle(color: _textDark, fontSize: 14),
              cursorColor: _brand,
              decoration: _dialogFieldDecoration('Current Password'),
              onChanged: (v) => currentPw = v,
            ),
            const SizedBox(height: 12),
            TextFormField(
              obscureText: true,
              style: const TextStyle(color: _textDark, fontSize: 14),
              cursorColor: _brand,
              decoration: _dialogFieldDecoration('New Password'),
              onChanged: (v) => newPw = v,
            ),
            const SizedBox(height: 12),
            TextFormField(
              obscureText: true,
              style: const TextStyle(color: _textDark, fontSize: 14),
              cursorColor: _brand,
              decoration: _dialogFieldDecoration('Confirm Password'),
              onChanged: (v) => confirmPw = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: _brandMuted),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, (currentPw, newPw, confirmPw)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandSoft,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final (cp, np, cnp) = result;
    if (cp.isEmpty || np.isEmpty || cnp.isEmpty) {
      _showMessage('Please fill all password fields.');
      return;
    }
    if (np.length < 3) {
      _showMessage('Use at least 3 characters for new password.');
      return;
    }
    if (np != cnp) {
      _showMessage('New password and confirmation do not match.');
      return;
    }
    await _savePassword(currentPassword: cp, newPassword: np);
  }

  Widget _buildAvatar(AppUser? user) {
    final hasImage = user?.hasProfileImage ?? false;
    final username = user?.username ?? 'Profile';

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 108,
          height: 108,
          decoration: const BoxDecoration(
            color: _brand,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: CircleAvatar(
              radius: 46,
              backgroundColor: _brandLight,
              backgroundImage: hasImage
                  ? MemoryImage(base64Decode(user!.profileImageBase64))
                  : null,
              child: hasImage
                  ? null
                  : Text(
                      _initials(username),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: _brand,
                      ),
                    ),
            ),
          ),
        ),
        Positioned(
          bottom: 2,
          right: 2,
          child: GestureDetector(
            onTap: _isSavingPhoto ? null : _showPhotoSourcePicker,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: _brandSoft,
                shape: BoxShape.circle,
              ),
              child: _isSavingPhoto
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _brandMuted,
          letterSpacing: 0.7,
        ),
      ),
    ),
  );

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconBg,
    Color? iconColor,
    Color? titleColor,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconBg ?? _brandLight,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: iconColor ?? _brand, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: titleColor ?? _textDark,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: _textHint),
            )
          : null,
      trailing:
          trailing ?? const Icon(Icons.chevron_right, color: _brandBorder),
      onTap: onTap,
    );
  }

  Widget _card(List<Widget> children) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _brandBorder),
    ),
    child: Column(
      children: children
          .asMap()
          .entries
          .map(
            (e) => Column(
              children: [
                e.value,
                if (e.key < children.length - 1)
                  const Divider(height: 1, color: Color(0xFFF0F2FF)),
              ],
            ),
          )
          .expand((w) => w.children)
          .toList(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _brandLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _brandBorder),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _brand),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _brand,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: StreamBuilder<AppUser?>(
          stream: _userService.streamUserByUid(_currentUid),
          builder: (context, snapshot) {
            final user = snapshot.data;
            final description = user?.description.trim() ?? '';

            return Column(
              children: [
                _buildAvatar(user),
                const SizedBox(height: 16),

                if (user != null) ...[
                  Text(
                    user.username,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: _brand,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: const TextStyle(fontSize: 13, color: _textHint),
                  ),
                  const SizedBox(height: 24),
                ],

                _sectionLabel('About'),
                _card([
                  _settingsTile(
                    icon: Icons.info_outline,
                    title: 'Description',
                    subtitle: description.isEmpty
                        ? 'No description added yet.'
                        : description,
                    trailing: const SizedBox.shrink(),
                    onTap: null,
                  ),
                ]),
                const SizedBox(height: 8),

                _sectionLabel('Settings'),
                _card([
                  _settingsTile(
                    icon: Icons.edit_outlined,
                    title: 'Edit Description',
                    onTap: user == null || _isUpdatingProfile
                        ? null
                        : () => _showEditDescriptionDialog(user),
                  ),
                  _settingsTile(
                    icon: Icons.person_outline,
                    title: 'Edit Username',
                    onTap: user == null || _isUpdatingProfile
                        ? null
                        : () => _showEditUsernameDialog(user),
                  ),
                  _settingsTile(
                    icon: Icons.lock_outline,
                    title: 'Edit Password',
                    onTap: _isUpdatingProfile ? null : _showEditPasswordDialog,
                  ),
                ]),

                if (_isUpdatingProfile) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: const LinearProgressIndicator(
                      minHeight: 2,
                      color: _brand,
                      backgroundColor: _brandBorder,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                _card([
                  _settingsTile(
                    icon: Icons.logout_outlined,
                    title: 'Log Out',
                    iconBg: const Color(0xFFFFF0F0),
                    iconColor: Colors.redAccent,
                    titleColor: Colors.redAccent,
                    onTap: () async {
                      await SessionService.instance.clearStayLoggedIn();
                      await AuthService.instance.signOut();
                      if (!context.mounted) return;
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.login,
                        (_) => false,
                      );
                    },
                  ),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }
}
