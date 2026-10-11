import 'package:flutter/material.dart';
import '../login/login_page.dart';

// ---------------------------------------------------------------------------
// Landing page tokens. Kept deliberately separate from the in-app theme
// (user_theme.dart / admin_theme.dart) because a marketing surface has
// different spacing and type requirements than a data-dense product UI.
// The values are the same neutral scale, but nothing here leaks into the
// product screens and nothing from the product screens leaks in.
// ---------------------------------------------------------------------------
class _Tok {
  static const bg          = Color(0xFF0E0F10);
  static const surface     = Color(0xFF161719);
  static const border      = Color(0xFF2A2B2F);

  static const textHi      = Color(0xFFECECEC);
  static const textMid     = Color(0xFFA6A7AC);
  static const textLo      = Color(0xFF6E7075);

  static const brand       = Color(0xFFB3261E);
  static const ok          = Color(0xFF3FB950);

  static const rSm = 4.0;
  static const rMd = 6.0;

  static const stack = 'system-ui, -apple-system, "Segoe UI", "Helvetica Neue", Arial, sans-serif';

  static const wordmark = TextStyle(
    fontFamily: stack,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: textHi,
    letterSpacing: -0.3,
  );
  static const h1 = TextStyle(
    fontFamily: stack,
    fontSize: 40,
    fontWeight: FontWeight.w600,
    color: textHi,
    letterSpacing: -1.0,
    height: 1.15,
  );
  static const subtitle = TextStyle(
    fontFamily: stack,
    fontSize: 15,
    color: textMid,
    height: 1.55,
  );
  static const caption = TextStyle(
    fontFamily: stack,
    fontSize: 12,
    color: textLo,
    height: 1.5,
  );
  static const label = TextStyle(
    fontFamily: stack,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: textLo,
    letterSpacing: 0.6,
  );
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  void _goToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Tok.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Nav(onLogin: () => _goToLogin(context)),
            Expanded(child: _Hero(onLogin: () => _goToLogin(context))),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NAV — brand lockup on the left, one action on the right. Nothing else.
// A landing page doesn't need About/Contact/Help until those pages exist;
// dead links that trigger a "not yet implemented" snackbar are worse than
// no links at all.
// ---------------------------------------------------------------------------
class _Nav extends StatelessWidget {
  final VoidCallback onLogin;
  const _Nav({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _Tok.border)),
      ),
      child: Row(
        children: [
          Image.asset('assets/images/logo.png', height: 26),
          const SizedBox(width: 10),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontFamily: _Tok.stack,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
              children: [
                TextSpan(text: 'Pyra', style: TextStyle(color: _Tok.ok)),
                TextSpan(text: 'Check', style: TextStyle(color: _Tok.brand)),
              ],
            ),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: onLogin,
            style: OutlinedButton.styleFrom(
              foregroundColor: _Tok.textHi,
              side: const BorderSide(color: _Tok.border),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_Tok.rMd),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HERO — logo, agency line, headline, subhead, one action.
// Reads top to bottom as: who (logo + agency), what (headline), how
// (subhead), do it (button).
// ---------------------------------------------------------------------------
class _Hero extends StatelessWidget {
  final VoidCallback onLogin;
  const _Hero({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Who this is
              Image.asset('assets/images/logo.png', height: 96),
              const SizedBox(height: 20),
              const Text('BUREAU OF FIRE PROTECTION', style: _Tok.label),
              const SizedBox(height: 4),
              const Text(
                'San Francisco, Agusan del Sur',
                style: _Tok.caption,
              ),

              const SizedBox(height: 40),

              // What it does
              const Text(
                'Fire safety inspections and certification, tracked end to end.',
                textAlign: TextAlign.center,
                style: _Tok.h1,
              ),
              const SizedBox(height: 16),
              const Text(
                'Submit an inspection request, monitor its progress, and '
                    'retrieve your official Fire Safety Clearance — all from '
                    'one portal.',
                textAlign: TextAlign.center,
                style: _Tok.subtitle,
              ),

              const SizedBox(height: 32),

              // Do it
              ElevatedButton(
                onPressed: onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Tok.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_Tok.rMd),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Access the BFP portal'),
              ),
              const SizedBox(height: 14),
              const Text(
                'For BFP personnel, encoders, and establishment representatives.',
                textAlign: TextAlign.center,
                style: _Tok.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FOOTER — one row, institutional. Gives the page a floor and states the
// operating condition of the service, which matters for a public-facing
// government tool.
// ---------------------------------------------------------------------------
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _Tok.border)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Bureau of Fire Protection · San Francisco, Agusan del Sur',
              style: _Tok.caption,
            ),
          ),
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              color: _Tok.ok,
              shape: BoxShape.circle,
            ),
          ),
          const Text('Systems operational', style: _Tok.caption),
          const SizedBox(width: 24),
          const Text('For emergencies, dial 911', style: _Tok.caption),
        ],
      ),
    );
  }
}