import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_model.dart';
import '../user_theme.dart';

class DashboardTab extends StatelessWidget {
  final void Function(int) onTabRequested;
  final void Function(Map<String, dynamic>) onViewCertificate;

  const DashboardTab({
    super.key,
    required this.onTabRequested,
    required this.onViewCertificate,
  });

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final colors = context.colors;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inspection_requests')
          .where('uid', isEqualTo: user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot>[];
        int pending = 0;
        int completed = 0;

        for (final doc in docs) {
          final status = (doc.data() as Map)['status'] ?? '';
          if (status == 'completed') {
            completed++;
          } else {
            pending++;
          }
        }
        final total = docs.length;

        return FutureBuilder<UserModel?>(
          future: Provider.of<AuthService>(context, listen: false)
              .getUserData(user?.uid ?? ''),
          builder: (context, userSnapshot) {
            final firstName =
                userSnapshot.data?.fullName.split(' ').first ?? 'there';

            return RefreshIndicator(
              color: Tok.brand,
              backgroundColor: colors.surface,
              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 400));
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: Tok.gap12),

                  // ── Greeting ─────────────────────────────────────────
                  Text('Hello, $firstName',
                      style: Tok.h1.copyWith(color: colors.textHi)),
                  const SizedBox(height: Tok.gap4),
                  Text(
                    'Your property safety status at a glance.',
                    style: Tok.bodySm.copyWith(color: colors.textMid),
                  ),
                  const SizedBox(height: Tok.gap20),

                  // ── Status panel ─────────────────────────────────────
                  _StatusPanel(
                    completed: completed,
                    pending: pending,
                    total: total,
                  ),

                  const SizedBox(height: Tok.gap20),

                  // ── Primary action ───────────────────────────────────
                  _PrimaryActionCard(
                    onTap: () => onTabRequested(2),
                  ),

                  const SizedBox(height: Tok.gap32),

                  // ── Certificates ─────────────────────────────────────
                  _SectionTitle('Certificates', color: colors.textHi),
                  const SizedBox(height: Tok.gap12),
                  _IssuedCertificates(
                    uid: user?.uid ?? '',
                    onOpen: onViewCertificate,
                  ),

                  const SizedBox(height: Tok.gap32),

                  // ── Recent activity ──────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _SectionTitle(
                          'Recent activity',
                          color: colors.textHi,
                        ),
                      ),
                      TextButton(
                        onPressed: () => onTabRequested(1),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.textMid,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        child: const Text('See All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: Tok.gap8),
                  _RecentActivity(
                    docs: docs,
                    onOpen: () => onTabRequested(1),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ===========================================================================
// Status panel
// ===========================================================================
class _StatusPanel extends StatelessWidget {
  final int completed;
  final int pending;
  final int total;
  const _StatusPanel({
    required this.completed,
    required this.pending,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final certified = completed > 0;
    final accent = certified ? Tok.ok : Tok.warn;

    final String stateLabel;
    final String headline;
    final String subline;

    if (total == 0) {
      stateLabel = 'NOT STARTED';
      headline = 'No inspections on file';
      subline = 'Submit a request to get started.';
    } else if (certified) {
      stateLabel = 'CERTIFIED';
      headline = 'Your property is compliant.';
      subline = '$completed Completed · $pending In Progress';
    } else {
      stateLabel = 'PENDING';
      headline = 'Inspection in progress.';
      subline = '$pending request${pending == 1 ? "" : "s"} Awaiting completion.';
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(Tok.rLg),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: Tok.gap6),
                        Text(
                          stateLabel,
                          style: Tok.label.copyWith(
                            color: accent,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Tok.gap12),
                    Text(headline,
                        style: Tok.h3.copyWith(color: colors.textHi)),
                    const SizedBox(height: Tok.gap4),
                    Text(subline,
                        style: Tok.bodySm.copyWith(color: colors.textMid)),
                    if (total > 0) ...[
                      const SizedBox(height: Tok.gap16),
                      Divider(height: 1, color: colors.borderSoft),
                      const SizedBox(height: Tok.gap12),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniStat(label: 'Total', value: '$total'),
                          ),
                          Expanded(
                            child: _MiniStat(
                                label: 'Completed', value: '$completed'),
                          ),
                          Expanded(
                            child: _MiniStat(
                                label: 'Pending', value: '$pending'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: Tok.label.copyWith(color: colors.textLo)),
        const SizedBox(height: Tok.gap4),
        Text(value, style: Tok.metric.copyWith(color: colors.textHi)),
      ],
    );
  }
}

// ===========================================================================
// Primary action
// ===========================================================================
class _PrimaryActionCard extends StatelessWidget {
  final VoidCallback onTap;
  const _PrimaryActionCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tok.brand,
      borderRadius: BorderRadius.circular(Tok.rLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tok.rLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(Tok.rSm),
                ),
                child: const Icon(
                  Icons.add_task_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: Tok.gap12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request an Inspection',
                      style: TextStyle(
                        fontFamily: Tok.stack,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Schedule a new fire safety audit',
                      style: TextStyle(
                        fontFamily: Tok.stack,
                        fontSize: 11,
                        color: Color(0xFFFFD9B3),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Section title
// ===========================================================================
class _SectionTitle extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionTitle(this.text, {required this.color});

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Tok.h3.copyWith(color: color));
}

// ===========================================================================
// Certificates
// ===========================================================================
class _IssuedCertificates extends StatelessWidget {
  final String uid;
  final void Function(Map<String, dynamic>) onOpen;
  const _IssuedCertificates({required this.uid, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inspection_requests')
          .where('uid', isEqualTo: uid)
          .where('certificate_status', isEqualTo: 'issued')
          .snapshots(),
      builder: (context, snapshot) {
        final colors = context.colors;

        if (snapshot.hasError) {
          return const _InlineMessage(
            icon: Icons.error_outline_rounded,
            message: 'Could not load certificates.',
          );
        }
        if (!snapshot.hasData) {
          return SizedBox(
            height: 56,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.textLo,
                ),
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const _InlineMessage(
            icon: Icons.verified_outlined,
            message: 'No certificates issued yet.',
          );
        }

        return Column(
          children: [
            for (var i = 0; i < docs.length; i++) ...[
              _CertificateRow(
                data: docs[i].data() as Map<String, dynamic>,
                onTap: () => onOpen(docs[i].data() as Map<String, dynamic>),
              ),
              if (i < docs.length - 1) const SizedBox(height: Tok.gap8),
            ],
          ],
        );
      },
    );
  }
}

class _CertificateRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _CertificateRow({required this.data, required this.onTap});

  String _fmtDate(dynamic ts) {
    if (ts is! Timestamp) return '';
    final d = ts.toDate();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final expTs = data['expiration_date'] as Timestamp?;
    final isExpired = expTs != null && expTs.toDate().isBefore(DateTime.now());
    final expStr = _fmtDate(expTs);

    return Container(
      decoration: flatBoxFrom(colors),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (isExpired ? Tok.danger : Tok.ok).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Tok.rSm),
                ),
                child: Icon(
                  isExpired ? Icons.event_busy_rounded : Icons.verified_outlined,
                  size: 18,
                  color: isExpired ? Tok.danger : Tok.ok,
                ),
              ),
              const SizedBox(width: Tok.gap12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['property_name'] ?? 'Certificate',
                      style: Tok.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textHi,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      expStr.isNotEmpty
                          ? (isExpired ? 'Expired: $expStr' : 'Valid until: $expStr')
                          : 'Fire Safety Clearance',
                      style: Tok.caption.copyWith(
                        color: isExpired ? Tok.danger : colors.textLo,
                        fontWeight: isExpired ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Tok.gap8),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Tok.rSm),
                  border: Border.all(color: colors.border),
                ),
                child: Icon(
                  Icons.download_rounded,
                  size: 16,
                  color: colors.textMid,
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
// Recent activity
// ===========================================================================
class _RecentActivity extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final VoidCallback onOpen;
  const _RecentActivity({required this.docs, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (docs.isEmpty) {
      return const _InlineMessage(
        icon: Icons.history_rounded,
        message: 'No recent activity.',
      );
    }

    final recent = docs.take(3).toList();

    return Container(
      decoration: flatBoxFrom(colors),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < recent.length; i++) ...[
            _ActivityRow(
              data: recent[i].data() as Map<String, dynamic>,
              onTap: onOpen,
            ),
            if (i < recent.length - 1)
              Divider(
                height: 1,
                color: colors.borderSoft,
                indent: 62,
              ),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _ActivityRow({required this.data, required this.onTap});

  /// Status colors are semantic and identical in both themes.
  static Color statusColor(String status) {
    switch (status) {
      case 'pending_approval':              return Tok.warn;
      case 'approved_waiting_requirements': return Tok.info;
      case 'requirements_submitted':        return Tok.purple;
      case 'assigned':                      return Tok.indigo;
      case 'completed':                     return Tok.ok;
      default:                              return const Color(0xFF6E7075); // neutral fallback
    }
  }

  static IconData statusIcon(String status) {
    switch (status) {
      case 'pending_approval':
        return Icons.hourglass_empty_rounded;
      case 'approved_waiting_requirements':
        return Icons.upload_file_outlined;
      case 'requirements_submitted':
        return Icons.fact_check_outlined;
      case 'assigned':
        return Icons.person_pin_circle_outlined;
      case 'completed':
        return Icons.verified_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final status = (data['status'] ?? 'pending_approval').toString();
    final color = statusColor(status);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(Tok.rSm),
              ),
              child: Icon(statusIcon(status), size: 18, color: color),
            ),
            const SizedBox(width: Tok.gap12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['property_name'] ?? 'Inspection',
                    style: Tok.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textHi,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data['inspection_type'] ?? 'Fire audit',
                    style: Tok.caption.copyWith(color: colors.textLo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Tok.gap8),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colors.textLo,
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Inline message
// ===========================================================================
class _InlineMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  const _InlineMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: flatBoxFrom(colors),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.textLo),
          const SizedBox(width: Tok.gap12),
          Expanded(
            child: Text(message,
                style: Tok.bodySm.copyWith(color: colors.textMid)),
          ),
        ],
      ),
    );
  }
}