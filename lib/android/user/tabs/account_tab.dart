import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../user_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/user_service.dart';
import '../../../services/theme_provider.dart';

class AccountTab extends StatefulWidget {
  const AccountTab({super.key});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  bool _isUploading = false;

  Future<void> _updateProfilePic() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 20,
      maxWidth: 512,
      maxHeight: 512,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await image.readAsBytes();
      if (bytes.length > 500000) throw 'Image is too large.';
      final base64String = base64Encode(bytes);

      if (!mounted) return;
      final userService = Provider.of<UserService>(context, listen: false);
      final user = userService.currentUser;
      if (user == null) return;

      await userService.updateProfilePicture(user.uid, base64String);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated'),
            backgroundColor: Tok.ok,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: Tok.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showChangePasswordDialog(UserModel? userData) {
    final colors = context.colors;

    if (userData?.lastPasswordChange != null) {
      final difference =
      DateTime.now().difference(userData!.lastPasswordChange!);
      if (difference.inDays < 3) {
        final remainingDays = 3 - difference.inDays;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You can change your password again in $remainingDays day${remainingDays > 1 ? "s" : ""}.',
            ),
            backgroundColor: Tok.warn,
          ),
        );
        return;
      }
    }

    final passController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: colors.surface,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tok.rMd),
          side: BorderSide(color: colors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Change password',
                          style: Tok.h2.copyWith(color: colors.textHi)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: colors.textLo),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.borderSoft),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New password',
                        style: Tok.label.copyWith(color: colors.textMid)),
                    const SizedBox(height: 6),
                    _TextField(
                      controller: passController,
                      hint: 'Enter at least 6 characters',
                      autofocus: true,
                      obscure: true,
                    ),
                    const SizedBox(height: 16),
                    Text('Confirm new password',
                        style: Tok.label.copyWith(color: colors.textMid)),
                    const SizedBox(height: 6),
                    _TextField(
                      controller: confirmController,
                      hint: 'Re-enter your new password',
                      obscure: true,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.borderSoft),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text('Cancel',
                          style: TextStyle(color: colors.textMid)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final newPass = passController.text.trim();
                        final confirmPass = confirmController.text.trim();

                        if (newPass.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password too short'),
                              backgroundColor: Tok.danger,
                            ),
                          );
                          return;
                        }

                        if (newPass != confirmPass) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Passwords do not match'),
                              backgroundColor: Tok.danger,
                            ),
                          );
                          return;
                        }

                        try {
                          final userService = Provider.of<UserService>(context, listen: false);
                          await userService.updatePassword(newPass);

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password updated successfully'),
                              backgroundColor: Tok.ok,
                            ),
                          );
                          setState(() {});
                        } on FirebaseAuthException catch (e) {
                          if (e.code == 'requires-recent-login') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Security: Please sign out and sign in again to change password.',
                                ),
                                backgroundColor: Tok.warn,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.message}'),
                                backgroundColor: Tok.danger,
                              ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Tok.danger,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Tok.brand,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Tok.rSm),
                        ),
                      ),
                      child: const Text('Update'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final userService = Provider.of<UserService>(context);
    final User? user = userService.currentUser;

    return FutureBuilder<UserModel?>(
      future: userService.getUserData(user?.uid ?? ''),
      builder: (context, snapshot) {
        final userData = snapshot.data;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Avatar ────────────────────────────────────────────
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: colors.border, width: 2),
                        image: userData?.profilePicBase64 != null
                            ? DecorationImage(
                          image: MemoryImage(
                            base64Decode(userData!.profilePicBase64!),
                          ),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: userData?.profilePicBase64 == null
                          ? Text(
                        getInitials(userData?.fullName ?? 'U'),
                        style: TextStyle(
                          color: colors.textHi,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _isUploading ? null : _updateProfilePic,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Tok.brand,
                            shape: BoxShape.circle,
                          ),
                          child: _isUploading
                              ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.camera_alt_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  userData?.fullName ?? '…',
                  style: Tok.h2.copyWith(color: colors.textHi),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 2),
              Center(
                child: Text(
                  user?.email ?? '',
                  style: Tok.bodySm.copyWith(color: colors.textMid),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // ── Personal information ─────────────────────────────
              Text('Personal Information',
                  style: Tok.h3.copyWith(color: colors.textHi)),
              const SizedBox(height: 8),
              _SettingsGroup(children: [
                _SettingsRow(
                  label: 'Full Name',
                  value: userData?.fullName ?? '—',
                  onTap: () => _showEditDialog(
                    'full_name',
                    'Full name',
                    userData?.fullName ?? '',
                  ),
                ),
                _SettingsRow(
                  label: 'Phone Number',
                  value: userData?.phone ?? 'Not set',
                  onTap: () => _showEditDialog(
                    'phone',
                    'Phone number',
                    userData?.phone ?? '',
                  ),
                ),
              ]),

              const SizedBox(height: 24),

              // ── Security & identity ──────────────────────────────
              Text('Security & Identity',
                  style: Tok.h3.copyWith(color: colors.textHi)),
              const SizedBox(height: 8),
              _SettingsGroup(children: [
                _SettingsRow(
                  label: 'Account ID',
                  value: (userData?.uid != null && userData!.uid.length >= 10)
                      ? userData.uid.substring(0, 10).toUpperCase()
                      : (userData?.uid ?? '—'),
                ),
                _SettingsRow(
                  label: 'Password',
                  value: '••••••••',
                  onTap: () => _showChangePasswordDialog(userData),
                ),
              ]),

              const SizedBox(height: 24),

              // ── Preferences ──────────────────────────────────────
              Text('Preferences',
                  style: Tok.h3.copyWith(color: colors.textHi)),
              const SizedBox(height: 8),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return _SettingsGroup(children: [
                    _SettingsToggleRow(
                      label: 'Dark mode',
                      subtitle: themeProvider.isDarkMode
                          ? 'Dark theme active'
                          : 'Light theme active',
                      value: themeProvider.isDarkMode,
                      icon: themeProvider.isDarkMode
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      onChanged: (val) => themeProvider.toggleTheme(val),
                    ),
                    const _SettingsRow(
                      label: 'Notifications',
                      value: 'All enabled',
                    ),
                    const _SettingsRow(
                      label: 'Language',
                      value: 'English (US)',
                    ),
                  ]);
                },
              ),

              const SizedBox(height: 32),

              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => Provider.of<UserService>(context, listen: false).signOut(),
                  icon: const Icon(Icons.logout_rounded,
                      size: 16, color: Tok.danger),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(
                      color: Tok.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: Tok.danger.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Tok.rMd),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'BFP · San Francisco, Agusan del Sur',
                  style: Tok.caption.copyWith(color: colors.textLo),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(String fieldKey, String label, String currentVal) {
    final colors = context.colors;
    final controller = TextEditingController(text: currentVal);

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: colors.surface,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tok.rMd),
          side: BorderSide(color: colors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Edit $label',
                          style: Tok.h2.copyWith(color: colors.textHi)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: colors.textMid),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.borderSoft),
              Padding(
                padding: const EdgeInsets.all(20),
                child: _TextField(
                  controller: controller,
                  hint: label,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                ),
              ),
              Divider(height: 1, color: colors.borderSoft),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                          foregroundColor: colors.textMid),
                      child: const Text('Cancel',
                          style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final userService = Provider.of<UserService>(context, listen: false);
                        final user = userService.currentUser;
                        if (user == null) return;
                        await userService.updateUserData(
                            user.uid, {fieldKey: controller.text.trim()});
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (!mounted) return;
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$label updated'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Tok.ok,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Tok.brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Tok.rSm),
                        ),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Settings primitives
// ===========================================================================
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: flatBoxFrom(colors),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, color: colors.borderSoft, indent: 16),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _SettingsRow({
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Tok.body.copyWith(color: colors.textHi)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: Tok.bodySm.copyWith(color: colors.textMid)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.edit_outlined, size: 16, color: colors.textLo)
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final bool obscure;
  final TextInputAction? textInputAction;

  const _TextField({
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.obscure = false,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      obscureText: obscure,
      textInputAction: textInputAction,
      style: Tok.body.copyWith(color: colors.textHi),
      cursorColor: colors.textHi,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: Tok.body.copyWith(color: colors.textLo),
        filled: true,
        fillColor: colors.surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tok.rMd),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tok.rMd),
          borderSide: const BorderSide(color: Tok.brand, width: 1.4),
        ),
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final IconData icon;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Tok.brandSoft),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Tok.body.copyWith(color: colors.textHi)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: Tok.bodySm.copyWith(color: colors.textMid)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: Tok.brand,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}