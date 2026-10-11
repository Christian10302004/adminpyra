import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../user_theme.dart';

class ReportsTab extends StatelessWidget {
  final Function(int) onTabRequested;
  final Future<void> Function(String) onUploadRequirement;
  final Future<void> Function(String) onSubmitRequirements;
  final Function(String) onViewEvidence;
  final VoidCallback onViewCertificate;

  const ReportsTab({
    super.key,
    required this.onTabRequested,
    required this.onUploadRequirement,
    required this.onSubmitRequirements,
    required this.onViewEvidence,
    required this.onViewCertificate,
  });

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inspection_requests')
          .where('uid', isEqualTo: user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingBlock();
        }
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return EmptyBlock(
            icon: Icons.description_outlined,
            title: 'No reports yet',
            body: 'Submit a request to start tracking your inspections.',
            action: SmallPrimaryButton(
              label: 'Create first request',
              onPressed: () => onTabRequested(2),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _ReportTile(
              docId: doc.id,
              data: data,
              onUploadRequirement: onUploadRequirement,
              onSubmitRequirements: onSubmitRequirements,
              onViewEvidence: onViewEvidence,
              onViewCertificate: onViewCertificate,
              statusColor: (s) => _getStatusColor(context, s),
              statusIcon: _getStatusIcon,
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(BuildContext context, String status) {
    switch (status) {
      case 'pending_approval':              return Tok.warn;
      case 'approved_waiting_requirements': return Tok.info;
      case 'requirements_submitted':        return Tok.purple;
      case 'assigned':                      return Tok.indigo;
      case 'completed':                     return Tok.ok;
      default:                              return context.colors.textLo;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending_approval':              return Icons.hourglass_empty_rounded;
      case 'approved_waiting_requirements': return Icons.upload_file_outlined;
      case 'requirements_submitted':        return Icons.fact_check_outlined;
      case 'assigned':                      return Icons.person_pin_circle_outlined;
      case 'completed':                     return Icons.verified_outlined;
      default:                              return Icons.assignment_outlined;
    }
  }
}

class _ReportTile extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Future<void> Function(String) onUploadRequirement;
  final Future<void> Function(String) onSubmitRequirements;
  final void Function(String base64) onViewEvidence;
  final VoidCallback onViewCertificate;
  final Color Function(String) statusColor;
  final IconData Function(String) statusIcon;

  const _ReportTile({
    required this.docId,
    required this.data,
    required this.onUploadRequirement,
    required this.onSubmitRequirements,
    required this.onViewEvidence,
    required this.onViewCertificate,
    required this.statusColor,
    required this.statusIcon,
  });

  String _getDisplayStatus(String status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'pending_approval':
        return 'Pending Approval';
      case 'approved_waiting_requirements':
        return 'Awaiting Requirements';
      case 'requirements_submitted':
        return 'Requirements Submitted';
      case 'assigned':
        return 'Assigned';
      default:
        return status.replaceAll('_', ' ').split(' ').map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1);
        }).join(' ');
    }
  }

  void _showCertificateModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CertificateModal(
        base64Data: data['certificate_base64'],
        fileName: 'Certificate_${data['property_name'] ?? 'Inspection'}.pdf', // Default name
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rawStatus = (data['status'] ?? 'pending_approval').toString();
    final color = statusColor(rawStatus);
    final displayStatus = _getDisplayStatus(rawStatus);

    final childrenList = <Widget>[
      Divider(height: 1, color: colors.borderSoft),
      const SizedBox(height: 12),

      SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(label: 'Inspection type', value: data['inspection_type'] ?? 'N/A'),
            const SizedBox(height: 10),
            _DetailRow(label: 'Address', value: data['address'] ?? 'N/A'),
            const SizedBox(height: 10),
            _DetailRow(
                label: 'Remarks',
                value: data['remarks'] ?? 'No special remarks provided.'),
          ],
        ),
      ),

      const SizedBox(height: 16),

      if (rawStatus == 'approved_waiting_requirements')
        _RequirementUpload(
          docId: docId,
          onUpload: onUploadRequirement,
          onSubmit: onSubmitRequirements,
        ),

      if (rawStatus == 'requirements_submitted')
        _InfoBanner(
          icon: Icons.check_circle_outline,
          color: Tok.purple,
          message: 'Requirements uploaded. Waiting for an inspector to be assigned.',
        ),

      if (data['evidence_base64'] != null) ...[
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => onViewEvidence(data['evidence_base64']),
          behavior: HitTestBehavior.opaque,
          child: _SecondaryButton(
            icon: Icons.image_search_outlined,
            label: 'View inspection evidence',
            onTap: () {},
          ),
        ),
      ],

      // --- CERTIFICATE BUTTON ---
      if (data['certificate_base64'] != null &&
          data['certificate_status'] == 'issued') ...[
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _showCertificateModal(context), // Trigger the modal
          behavior: HitTestBehavior.opaque,
          child: _SecondaryButton(
            icon: Icons.description_outlined,
            label: () {
              final exp = data['expiration_date'] as Timestamp?;
              if (exp != null) {
                final d = exp.toDate();
                final isExpired = d.isBefore(DateTime.now());
                final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                return isExpired
                    ? 'View Certificate (Expired on $dateStr)'
                    : 'View Certificate (Valid until $dateStr)';
              }
              return 'View Fire Safety Certificate';
            }(),
            onTap: () {},
          ),
        ),
      ] else if (data['certificate_status'] == 'pending_review') ...[
        const SizedBox(height: 10),
        _InfoBanner(
          icon: Icons.history_edu_rounded,
          color: Tok.info,
          message: "Certificate drafted. Awaiting the Fire Marshal's signature.",
        ),
      ],
    ];

    return Container(
      decoration: flatBoxFrom(colors),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: colors.textMid,
          collapsedIconColor: colors.textLo,
          leading: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Tok.rSm),
            ),
            child: Icon(statusIcon(rawStatus), size: 15, color: color),
          ),
          title: Text(
            data['property_name'] ?? 'Inspection',
            style: Tok.body.copyWith(
              fontWeight: FontWeight.w500,
              color: colors.textHi,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                _SmallTag(label: displayStatus, color: color),
              ],
            ),
          ),
          children: childrenList,
        ),
      ),
    );
  }
}

// ===========================================================================
// Certificate Modal (New Widget)
// ===========================================================================
class _CertificateModal extends StatelessWidget {
  final String base64Data;
  final String fileName;

  const _CertificateModal({
    required this.base64Data,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // 1. Decode Base64
    Uint8List bytes;
    try {
      bytes = base64Decode(base64Data);
    } catch (e) {
      return Container(
        height: 300,
        color: colors.bg,
        child: const Center(child: Text("Error: Invalid certificate data")),
      );
    }

    // 2. Detect if it's a PDF (checking magic numbers)
    // PDF files start with %PDF (0x25 0x50 0x44 0x46)
    bool isPdf = bytes.length > 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85, // 85% of screen height
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.borderSoft)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Certificate",
                  style: Tok.h3.copyWith(color: colors.textHi),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textMid),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: isPdf
                ? _PdfViewerPlaceholder(
              onOpen: () async {
                // Save to temp file and open with external app
                final tempDir = await getTemporaryDirectory();
                final file = File('${tempDir.path}/$fileName');
                await file.writeAsBytes(bytes);

                final uri = Uri.file(file.path);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Could not open PDF viewer")),
                    );
                  }
                }
              },
            )
                : InteractiveViewer(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Footer / Download Button
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final tempDir = await getTemporaryDirectory();
                  // Note: Saving to Downloads requires permission_handler on Android.
                  // For simplicity, we save to temp and let user share/open.
                  final file = File('${tempDir.path}/$fileName');
                  await file.writeAsBytes(bytes);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Saved to: ${file.path}"),
                        action: SnackBarAction(
                          label: "Open",
                          onPressed: () async {
                            final uri = Uri.file(file.path);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text("Download / Save"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Tok.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Tok.rSm),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfViewerPlaceholder extends StatelessWidget {
  final Future<void> Function() onOpen;
  const _PdfViewerPlaceholder({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf, size: 64, color: colors.textLo),
          const SizedBox(height: 16),
          Text(
            "PDF Document",
            style: Tok.h3.copyWith(color: colors.textHi),
          ),
          const SizedBox(height: 8),
          Text(
            "Preview not available in-app.",
            style: Tok.bodySm.copyWith(color: colors.textMid),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new),
            label: const Text("Open in Viewer"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Tok.brand,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Small pieces
// ===========================================================================
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Tok.label.copyWith(color: colors.textLo),
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: Tok.body.copyWith(color: colors.textHi),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
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

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: OutlinedButton.icon(
        onPressed: null, // Handled by parent GestureDetector
        icon: Icon(icon, size: 16, color: colors.textHi),
        label: Text(
          label,
          style: TextStyle(
            color: colors.textHi,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colors.border, width: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tok.rSm),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}

class SmallPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const SmallPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Tok.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tok.rSm),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

// ===========================================================================
// Info banner
// ===========================================================================
class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Tok.rSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Tok.bodySm.copyWith(color: color),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Requirement upload
// ===========================================================================
class _RequirementUpload extends StatelessWidget {
  final String docId;
  final Future<void> Function(String) onUpload;
  final Future<void> Function(String) onSubmit;
  const _RequirementUpload({
    required this.docId,
    required this.onUpload,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inspection_requests')
          .doc(docId)
          .collection('files')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.hasData ? snapshot.data!.docs : const [];

        return SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(height: 1, color: colors.borderSoft),
              const SizedBox(height: 12),
              Text('Required documents',
                  style: Tok.h3.copyWith(color: colors.textHi)),
              const SizedBox(height: 4),
              Text(
                'Upload up to 5 photos. Max 1 MB each.',
                style: Tok.caption.copyWith(color: colors.textLo),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(Tok.rSm),
                          child: Image.memory(
                            base64Decode(data['base64']),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () async {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('inspection_requests')
                                    .doc(docId)
                                    .collection('files')
                                    .doc(doc.id)
                                    .delete();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Document removed'),
                                      backgroundColor: Tok.warn,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                debugPrint('Error removing file: $e');
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  if (docs.length < 5)
                    InkWell(
                      onTap: () => onUpload(docId),
                      borderRadius: BorderRadius.circular(Tok.rSm),
                      child: Container(
                        width: 60,
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.bg,
                          borderRadius: BorderRadius.circular(Tok.rSm),
                          border: Border.all(color: colors.border),
                        ),
                        child: Icon(
                          Icons.add_a_photo_outlined,
                          color: colors.textMid,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
              if (docs.isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () => onSubmit(docId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Tok.ok,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Tok.rSm),
                      ),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Submit all requirements'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ===========================================================================
// Loading + empty
// ===========================================================================
class LoadingBlock extends StatelessWidget {
  const LoadingBlock({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: context.colors.textLo,
        ),
      ),
    );
  }
}

class EmptyBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  const EmptyBlock({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: colors.textLo),
            const SizedBox(height: 12),
            Text(title,
                style: Tok.h3.copyWith(color: colors.textHi),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(body,
                style: Tok.bodySm.copyWith(color: colors.textMid),
                textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}