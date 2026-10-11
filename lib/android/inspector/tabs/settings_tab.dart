import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../services/theme_provider.dart';
import '../inspector_theme.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    Provider.of<ThemeProvider>(context);
    final User? user = FirebaseAuth.instance.currentUser;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Tok.surfaceAlt,
                borderRadius: BorderRadius.circular(Tok.rMd),
                border: Border.all(color: Tok.border),
              ),
              child: Icon(
                Icons.engineering_outlined,
                size: 24,
                color: Tok.brandSoft,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              user?.email?.split('@').first ?? 'Inspector',
              style: Tok.h2,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              user?.email ?? '',
              style: Tok.bodySm,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Tok.surfaceAlt,
                borderRadius: BorderRadius.circular(Tok.rSm),
                border: Border.all(color: Tok.border),
              ),
              child: Text(
                'FIELD INSPECTOR',
                style: Tok.label.copyWith(
                  color: Tok.textMid,
                  fontSize: 10,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          Text('Preferences', style: Tok.h3),
          const SizedBox(height: 8),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return _SettingsGroup(children: [
                SwitchListTile(
                  title: Text(
                    'Dark Mode',
                    style: Tok.body.copyWith(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    themeProvider.isDarkMode
                        ? 'Dark theme enabled'
                        : 'Light theme enabled',
                    style: Tok.bodySm,
                  ),
                  value: themeProvider.isDarkMode,
                  activeThumbColor: Tok.brandSoft,
                  onChanged: (val) => themeProvider.toggleTheme(val),
                  secondary: Icon(
                    themeProvider.isDarkMode
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                    color: Tok.brandSoft,
                  ),
                ),
              ]);
            },
          ),

          const SizedBox(height: 24),

          Text('Account', style: Tok.h3),
          const SizedBox(height: 8),
          _SettingsGroup(children: [
            _SettingsRow(label: 'Contact number', value: 'Not set'),
            _SettingsRow(
              label: 'Reset password',
              value: 'Change access credentials',
              onTap: () {},
            ),
            _SettingsRow(
              label: 'Support center',
              value: 'Contact BFP administration',
              onTap: () {},
            ),
          ]),

          const SizedBox(height: 32),

          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => _showSignOutDialog(context),
              icon: Icon(
                Icons.logout_rounded,
                size: 16,
                color: Tok.danger,
              ),
              label: Text(
                'Sign out',
                style: TextStyle(
                  color: Tok.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Tok.danger.withValues(alpha: 0.4)),
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
              style: Tok.caption,
            ),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Tok.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tok.rMd),
          side: BorderSide(color: Tok.border),
        ),
        title: Text(
          'Sign out?',
          style: TextStyle(
            color: Tok.textHi,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of your inspector account?',
          style: TextStyle(color: Tok.textMid, fontSize: 13),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(foregroundColor: Tok.textMid),
            child: const Text('Cancel', style: TextStyle(fontSize: 13)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Tok.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Tok.rSm),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await FirebaseAuth.instance.signOut();
            },
            child: const Text(
              'Sign out',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tok.surface,
        borderRadius: BorderRadius.circular(Tok.rMd),
        border: Border.all(color: Tok.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                Divider(height: 1, color: Tok.borderSoft, indent: 16),
            ],
          ],
        ),
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
                  Text(label, style: Tok.body),
                  const SizedBox(height: 2),
                  Text(value, style: Tok.bodySm),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Tok.textLo,
              ),
          ],
        ),
      ),
    );
  }
}