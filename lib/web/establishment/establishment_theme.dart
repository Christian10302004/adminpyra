import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../../services/web_helper.dart';

class Tok {
  static bool isDark = true;

  // ── Surfaces ──────────────────────────────────────────────────────────
  static Color get bg => isDark ? const Color(0xFF0E0F10) : const Color(0xFFF8FAFC);
  static Color get surface => isDark ? const Color(0xFF161719) : const Color(0xFFFFFFFF);
  static Color get surfaceAlt => isDark ? const Color(0xFF1D1E21) : const Color(0xFFF1F5F9);
  static Color get border => isDark ? const Color(0xFF2A2B2F) : const Color(0xFFE2E8F0);
  static Color get borderSoft => isDark ? const Color(0xFF212225) : const Color(0xFFF1F5F9);

  // ── Text ──────────────────────────────────────────────────────────────
  static Color get textHi => isDark ? const Color(0xFFECECEC) : const Color(0xFF0F172A);
  static Color get textMid => isDark ? const Color(0xFFA6A7AC) : const Color(0xFF475569);
  static Color get textLo => isDark ? const Color(0xFF6E7075) : const Color(0xFF94A3B8);

  // ── Brand & semantic (identical in both modes) ────────────────────────
  static const brand = Color(0xFFB3261E);
  static const ok = Color(0xFF3FB950);
  static const warn = Color(0xFFD29922);
  static const info = Color(0xFF4C8DFF);
  static const danger = Color(0xFFF85149);
  static const purple = Color(0xFF8B5CF6);

  static const rSm = 4.0;
  static const rMd = 6.0;
  static const rLg = 8.0;

  static const stack = 'system-ui, -apple-system, "Segoe UI", "Helvetica Neue", Arial, sans-serif';

  static TextStyle get h1 => TextStyle(
    fontFamily: stack,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textHi,
    letterSpacing: -0.2,
    height: 1.2,
  );

  static TextStyle get h2 => TextStyle(
    fontFamily: stack,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textHi,
    letterSpacing: -0.1,
  );

  static TextStyle get body => TextStyle(
    fontFamily: stack,
    fontSize: 13,
    color: textHi,
    height: 1.4,
  );

  static TextStyle get bodySm => TextStyle(
    fontFamily: stack,
    fontSize: 12,
    color: textMid,
    height: 1.35,
  );

  static TextStyle get label => TextStyle(
    fontFamily: stack,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: textLo,
    letterSpacing: 0.5,
  );

  static TextStyle get num => TextStyle(
    fontFamily: stack,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textHi,
    letterSpacing: -0.5,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const SectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Tok.h1),
        const SizedBox(height: 3),
        Text(subtitle, style: Tok.bodySm.copyWith(color: Tok.textLo, fontSize: 12)),
      ],
    );
  }
}

class TableShell extends StatelessWidget {
  final Widget child;
  final Widget? header;
  final bool expandChild;

  const TableShell({
    super.key,
    required this.child,
    this.header,
    this.expandChild = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tok.surface,
        borderRadius: BorderRadius.circular(Tok.rLg),
        border: Border.all(color: Tok.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[
            header!,
            Divider(height: 1, color: Tok.borderSoft),
          ],
          if (expandChild)
            Expanded(child: child)
          else
            child,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: Tok.textLo),
          const SizedBox(height: 10),
          Text(title, style: Tok.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Tok.bodySm.copyWith(color: Tok.textLo),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class StatusTag extends StatelessWidget {
  final String status;

  const StatusTag({super.key, required this.status});

  static const _labels = <String, String>{
    'pending_approval': 'Pending',
    'approved_waiting_requirements': 'Awaiting docs',
    'requirements_submitted': 'Submitted',
    'assigned': 'Assigned',
    'completed': 'Completed',
  };

  static Color colorFor(String s) {
    switch (s) {
      case 'pending_approval':
        return Tok.warn;
      case 'approved_waiting_requirements':
        return Tok.info;
      case 'requirements_submitted':
        return Tok.purple;
      case 'assigned':
        return Tok.info;
      case 'completed':
        return Tok.ok;
      default:
        return Tok.textLo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    final label = _labels[status] ?? status.replaceAll('_', ' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Tok.rSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class CertIndicator extends StatelessWidget {
  final bool hasCert, inReview;
  final bool isExpired;

  const CertIndicator({
    super.key,
    required this.hasCert,
    required this.inReview,
    this.isExpired = false,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = hasCert
        ? (isExpired ? ('Expired', Tok.danger) : ('Issued', Tok.ok))
        : inReview
        ? ('In review', Tok.warn)
        : ('Not issued', Tok.textLo);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Tok.bodySm.copyWith(
            color: color,
            fontSize: 11,
            fontWeight: isExpired ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class RowActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const RowActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Tok.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tok.rMd),
        ),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class GhostIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const GhostIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Tok.rMd),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(Tok.rMd),
          hoverColor: Tok.surfaceAlt,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Tok.rMd),
              border: Border.all(color: Tok.border),
            ),
            child: Icon(icon, size: 15, color: Tok.textMid),
          ),
        ),
      ),
    );
  }
}

void showFullAuditDialog(BuildContext context, String docId, Map<String, dynamic> data) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Tok.surface,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tok.rLg),
        side: BorderSide(color: Tok.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (data['property_name'] ?? 'Audit record').toString(),
                          style: TextStyle(
                            fontFamily: Tok.stack,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Tok.textHi,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            StatusTag(status: (data['status'] ?? 'pending_approval').toString()),
                            const SizedBox(width: 10),
                            Text('·', style: Tok.bodySm.copyWith(color: Tok.textLo)),
                            const SizedBox(width: 10),
                            Text(
                              docId,
                              style: Tok.bodySm.copyWith(
                                color: Tok.textLo,
                                fontSize: 11,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, size: 18, color: Tok.textMid),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Tok.borderSoft),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AuditTimeline(data: data),
                    const SizedBox(height: 24),
                    _AuditDetailsSection(data: data),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _AuditColumn(
                            title: 'Requirement Files',
                            meta: 'Uploaded by property owner',
                            docId: docId,
                            subcollection: 'files',
                            emptyLabel: 'No requirement files found.',
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _AuditColumn(
                            title: 'Inspector Evidence',
                            meta: 'Evidence photos & AI detections',
                            docId: docId,
                            subcollection: 'evidence',
                            emptyLabel: 'No evidence photos found.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AuditTimeline extends StatelessWidget {
  final Map<String, dynamic> data;

  const _AuditTimeline({required this.data});

  static const _stages = <(String, String)>[
    ('Requested', 'requested_at'),
    ('Approved', 'approved_at'),
    ('Assigned', 'assigned_at'),
    ('Inspected', 'inspected_at'),
    ('Issued', 'issued_at'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PROCESS ARCHIVE', style: Tok.label),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final compact = c.maxWidth < 640;
            return Container(
              decoration: BoxDecoration(
                color: Tok.bg,
                borderRadius: BorderRadius.circular(Tok.rMd),
                border: Border.all(color: Tok.border),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 20,
                vertical: 16,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _stages.length; i++) ...[
                    Expanded(
                      child: _TimelineNode(
                        label: _stages[i].$1,
                        timestamp: data[_stages[i].$2],
                        isLast: i == _stages.length - 1,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TimelineNode extends StatelessWidget {
  final String label;
  final dynamic timestamp;
  final bool isLast;

  const _TimelineNode({
    required this.label,
    required this.timestamp,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final done = timestamp is Timestamp;
    final color = done ? Tok.ok : Tok.textLo;

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: done ? Tok.ok : Tok.bg,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: color),
                  ),
                ),
                const SizedBox(width: 8),
                Text(label, style: Tok.label.copyWith(color: Tok.textMid)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              done
                  ? (timestamp as Timestamp).toDate().toString().split(' ').first
                  : '—',
              style: Tok.bodySm.copyWith(
                color: done ? Tok.textHi : Tok.textLo,
                fontSize: 11,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        if (!isLast)
          Expanded(
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: done ? Tok.ok.withValues(alpha: 0.5) : Tok.border,
            ),
          ),
      ],
    );
  }
}

class _AuditDetailsSection extends StatelessWidget {
  final Map<String, dynamic> data;

  const _AuditDetailsSection({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PROPERTY & CLIENT INFORMATION', style: Tok.label),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Tok.bg,
            borderRadius: BorderRadius.circular(Tok.rMd),
            border: Border.all(color: Tok.border),
          ),
          child: Column(
            children: [
              _infoRow(Icons.business_rounded, 'Property', data['property_name'] ?? 'N/A'),
              Divider(height: 24, color: Tok.borderSoft),
              _infoRow(Icons.person_outline_rounded, 'Owner', data['full_name'] ?? data['email'] ?? 'N/A'),
              Divider(height: 24, color: Tok.borderSoft),
              _infoRow(Icons.phone_android_rounded, 'Contact', data['phone'] ?? 'N/A'),
              Divider(height: 24, color: Tok.borderSoft),
              _infoRow(Icons.location_on_outlined, 'Location', data['address'] ?? 'N/A'),
              Divider(height: 24, color: Tok.borderSoft),
              _infoRow(Icons.category_outlined, 'Inspection', data['inspection_type'] ?? 'N/A'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String val) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Tok.textLo),
        const SizedBox(width: 10),
        Text(label, style: Tok.bodySm.copyWith(color: Tok.textLo)),
        const Spacer(),
        Text(val, style: Tok.body.copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _AuditColumn extends StatelessWidget {
  final String title, meta, docId, subcollection, emptyLabel;

  const _AuditColumn({
    required this.title,
    required this.meta,
    required this.docId,
    required this.subcollection,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Tok.h2),
        const SizedBox(height: 2),
        Text(meta, style: Tok.bodySm.copyWith(color: Tok.textLo, fontSize: 11)),
        const SizedBox(height: 12),
        FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('inspection_requests')
              .doc(docId)
              .collection(subcollection)
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Tok.bg,
                  borderRadius: BorderRadius.circular(Tok.rSm),
                  border: Border.all(color: Tok.borderSoft),
                ),
                child: Text(emptyLabel, style: Tok.bodySm.copyWith(color: Tok.textLo)),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final base64 = data['base64'] as String?;
                final name = (data['name'] ?? data['file_name'] ?? 'Requirement Document').toString();
                final detections = (data['detections'] as List?) ?? const [];
                if (base64 == null || base64.isEmpty) return const SizedBox.shrink();

                bool isPdf = name.toLowerCase().endsWith('.pdf');
                if (!isPdf) {
                  try {
                    final bytes = base64Decode(base64);
                    isPdf = bytes.length > 4 &&
                        bytes[0] == 0x25 &&
                        bytes[1] == 0x50 &&
                        bytes[2] == 0x44 &&
                        bytes[3] == 0x46;
                  } catch (_) {}
                }

                return InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (dialogCtx) => Dialog(
                        backgroundColor: Tok.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Tok.rLg),
                          side: BorderSide(color: Tok.border),
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 750, maxHeight: 680),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                                child: Row(
                                  children: [
                                    Text(name, style: Tok.h2),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 18),
                                      onPressed: () => Navigator.pop(dialogCtx),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: Tok.borderSoft),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      if (isPdf)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(28),
                                          decoration: BoxDecoration(
                                            color: Tok.bg,
                                            borderRadius: BorderRadius.circular(Tok.rMd),
                                            border: Border.all(color: Tok.border),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.picture_as_pdf_rounded,
                                                  size: 64, color: Tok.danger),
                                              const SizedBox(height: 16),
                                              Text(name, style: Tok.h2, textAlign: TextAlign.center),
                                              const SizedBox(height: 6),
                                              Text('PDF Document', style: Tok.bodySm.copyWith(color: Tok.textLo)),
                                              const SizedBox(height: 24),
                                              Wrap(
                                                spacing: 12,
                                                runSpacing: 12,
                                                alignment: WrapAlignment.center,
                                                children: [
                                                  ElevatedButton.icon(
                                                    onPressed: () => openBase64InNewTab(base64, 'pdf'),
                                                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                                    label: const Text('Open PDF in New Tab'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Tok.brand,
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(Tok.rSm),
                                                      ),
                                                    ),
                                                  ),
                                                  OutlinedButton.icon(
                                                    onPressed: () => downloadBase64File(base64, name.replaceAll('.pdf', ''), 'pdf'),
                                                    icon: const Icon(Icons.download_rounded, size: 18),
                                                    label: const Text('Download PDF'),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: Tok.textHi,
                                                      side: BorderSide(color: Tok.border),
                                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(Tok.rSm),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(Tok.rMd),
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(maxHeight: 420),
                                            child: Image.memory(
                                              base64Decode(base64),
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      if (detections.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Tok.bg,
                                            borderRadius: BorderRadius.circular(Tok.rMd),
                                            border: Border.all(color: Tok.border),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.psychology_outlined, size: 16, color: Tok.info),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Roboflow AI Identified Safety Equipment',
                                                    style: TextStyle(
                                                      color: Tok.textHi,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: detections.map((d) {
                                                  final cls = (d['class'] ?? 'Equipment').toString();
                                                  final pct = (d['confidence_pct'] ?? '').toString();
                                                  return Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Tok.info.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(Tok.rSm),
                                                      border: Border.all(color: Tok.info.withValues(alpha: 0.3)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.smart_toy_outlined, size: 12, color: Tok.info),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          '$cls ${pct.isNotEmpty ? "($pct)" : ""}',
                                                          style: TextStyle(
                                                            color: Tok.textHi,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(Tok.rMd),
                  child: Stack(
                    children: [
                      if (isPdf)
                        Container(
                          width: 120,
                          height: 120,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Tok.bg,
                            borderRadius: BorderRadius.circular(Tok.rMd),
                            border: Border.all(color: Tok.border),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.picture_as_pdf_rounded, size: 36, color: Tok.danger),
                              const SizedBox(height: 6),
                              Text(
                                name,
                                style: TextStyle(fontSize: 10, color: Tok.textHi, fontWeight: FontWeight.w500),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(Tok.rMd),
                          child: Image.memory(
                            base64Decode(base64),
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 120,
                              height: 120,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Tok.bg,
                                borderRadius: BorderRadius.circular(Tok.rMd),
                                border: Border.all(color: Tok.border),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.picture_as_pdf_rounded, size: 36, color: Tok.danger),
                                  const SizedBox(height: 6),
                                  Text(
                                    name,
                                    style: TextStyle(fontSize: 10, color: Tok.textHi),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (detections.isNotEmpty)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xB3000000),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.smart_toy_outlined, size: 11, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  '${detections.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (subcollection == 'files')
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () async {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('inspection_requests')
                                    .doc(docId)
                                    .collection('files')
                                    .doc(doc.id)
                                    .delete();
                              } catch (e) {
                                debugPrint('Error removing file: $e');
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

void viewCertificate(BuildContext context, Map<String, dynamic> data) {
  final base64 = data['certificate_base64'] as String?;
  final ext = (data['certificate_extension'] ?? 'jpg').toString();
  final name = (data['certificate_filename'] ?? 'fire_safety_certificate').toString();
  if (base64 == null) return;

  final expTs = data['expiration_date'] as Timestamp?;
  final isExpired = expTs != null && expTs.toDate().isBefore(DateTime.now());
  final expStr = expTs != null
      ? '${expTs.toDate().year}-${expTs.toDate().month.toString().padLeft(2, '0')}-${expTs.toDate().day.toString().padLeft(2, '0')}'
      : null;

  if (ext.toLowerCase() == 'pdf') {
    openBase64InNewTab(base64, ext);
    return;
  }

  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Tok.surface,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tok.rLg),
        side: BorderSide(color: Tok.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Certificate', style: Tok.h2),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          style: Tok.bodySm.copyWith(color: Tok.textLo, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, size: 18, color: Tok.textMid),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Tok.borderSoft),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Tok.rMd),
                  child: Image.memory(base64Decode(base64), fit: BoxFit.contain),
                ),
              ),
            ),
            Divider(height: 1, color: Tok.borderSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  if (expStr != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (isExpired ? Tok.danger : Tok.ok).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(Tok.rSm),
                        border: Border.all(
                          color: (isExpired ? Tok.danger : Tok.ok).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        isExpired ? 'Expired: $expStr' : 'Valid until: $expStr',
                        style: TextStyle(
                          color: isExpired ? Tok.danger : Tok.ok,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close', style: TextStyle(color: Tok.textMid, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => downloadBase64File(base64, name, ext),
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: const Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Tok.brand,
                      foregroundColor: Colors.white,
                    ),
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

void showNewInspectionRequestDialog(BuildContext context) {
  final propNameCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final remarksCtrl = TextEditingController();
  String selectedBrgy = 'Barangay 1';
  String selectedType = 'Annual Fire Inspection';
  bool isSubmitting = false;

  final barangays = [
    'Barangay 1', 'Barangay 2', 'Barangay 3', 'Barangay 4', 'Barangay 5',
    'Alegria', 'Bayanihan', 'Buenasuerte', 'Caimpuogan', 'Ebro', 'Hubang',
    'Karaos', 'Ladgadan', 'Lapinigan', 'Lucena', 'Mate', 'New Ormoc',
    'Ormaca', 'Pasto', 'Pisaan', 'Rizal', 'San Isidro', 'Santa Ana',
    'Tagapua', 'Tibaje'
  ];

  final inspectionTypes = [
    'Annual Fire Inspection',
    'Business Permit',
    'New Occupancy Clearance',
    'Special Inspection',
  ];

  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) => Dialog(
        backgroundColor: Tok.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tok.rLg),
          side: BorderSide(color: Tok.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Request Fire Inspection', style: Tok.h2),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('PROPERTY NAME *', style: Tok.label),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: propNameCtrl,
                    style: Tok.body,
                    decoration: InputDecoration(
                      hintText: 'e.g., SM Mall / Main Store',
                      hintStyle: Tok.bodySm.copyWith(color: Tok.textLo),
                      filled: true,
                      fillColor: Tok.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Tok.rSm),
                        borderSide: BorderSide(color: Tok.border),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter property name' : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BARANGAY *', style: Tok.label),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: selectedBrgy,
                              dropdownColor: Tok.surface,
                              style: Tok.body,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Tok.bg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(Tok.rSm),
                                  borderSide: BorderSide(color: Tok.border),
                                ),
                              ),
                              items: barangays
                                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setDialogState(() => selectedBrgy = v);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('INSPECTION TYPE *', style: Tok.label),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: selectedType,
                              dropdownColor: Tok.surface,
                              style: Tok.body,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Tok.bg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(Tok.rSm),
                                  borderSide: BorderSide(color: Tok.border),
                                ),
                              ),
                              items: inspectionTypes
                                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setDialogState(() => selectedType = v);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('STREET ADDRESS *', style: Tok.label),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: addressCtrl,
                    style: Tok.body,
                    decoration: InputDecoration(
                      hintText: 'e.g., Door 3, Main Street',
                      hintStyle: Tok.bodySm.copyWith(color: Tok.textLo),
                      filled: true,
                      fillColor: Tok.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Tok.rSm),
                        borderSide: BorderSide(color: Tok.border),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter street address' : null,
                  ),
                  const SizedBox(height: 14),
                  Text('CONTACT PHONE NUMBER *', style: Tok.label),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: Tok.body,
                    decoration: InputDecoration(
                      hintText: '+63 900 000 0000',
                      hintStyle: Tok.bodySm.copyWith(color: Tok.textLo),
                      filled: true,
                      fillColor: Tok.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Tok.rSm),
                        borderSide: BorderSide(color: Tok.border),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter phone number' : null,
                  ),
                  const SizedBox(height: 14),
                  Text('REMARKS / NOTES', style: Tok.label),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: remarksCtrl,
                    style: Tok.body,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Any special notes for the BFP inspector',
                      hintStyle: Tok.bodySm.copyWith(color: Tok.textLo),
                      filled: true,
                      fillColor: Tok.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Tok.rSm),
                        borderSide: BorderSide(color: Tok.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: Text('Cancel', style: TextStyle(color: Tok.textMid)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);
                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            final fullAddr =
                                "${addressCtrl.text.trim()}, Barangay $selectedBrgy, San Francisco, Agusan del Sur";

                            await FirebaseFirestore.instance.collection('inspection_requests').add({
                              'uid': user?.uid,
                              'email': user?.email,
                              'full_name': user?.displayName ?? user?.email ?? 'Establishment Rep',
                              'property_name': propNameCtrl.text.trim(),
                              'address': fullAddr,
                              'barangay': selectedBrgy,
                              'phone': phoneCtrl.text.trim(),
                              'inspection_type': selectedType,
                              'remarks': remarksCtrl.text.trim(),
                              'status': 'pending_approval',
                              'requested_at': FieldValue.serverTimestamp(),
                            });

                            if (ctx.mounted) {
                              Navigator.pop(dialogCtx);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Inspection request submitted successfully!'),
                                  backgroundColor: Tok.ok,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Tok.danger,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Tok.brand,
                          foregroundColor: Colors.white,
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text('Submit Request'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}