import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import '../../../services/web_helper.dart';
import '../../../services/user_service.dart';
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
    final userService = Provider.of<UserService>(context);
    final user = userService.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: userService.streamUserInspectionRequests(user?.uid ?? ''),
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
      case 'resubmission_required':         return Tok.danger;
      case 'requirements_accepted_conditional': return Tok.warn;
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
      case 'resubmission_required':         return Icons.replay_rounded;
      case 'requirements_accepted_conditional': return Icons.assignment_late_outlined;
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
      case 'resubmission_required':
        return 'Resubmission Required';
      case 'requirements_accepted_conditional':
        return 'Accepted (Conditional)';
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
    final String? base64 = data['certificate_base64'];
    if (base64 == null || base64.isEmpty) return;

    final String ext = (data['certificate_extension'] ?? 'pdf').toString().toLowerCase();
    String fileName = (data['certificate_filename'] ?? '').toString();
    if (fileName.isEmpty) {
      final propName = (data['property_name'] ?? 'Inspection').toString().replaceAll(' ', '_');
      fileName = 'Certificate_$propName.$ext';
    } else if (!fileName.toLowerCase().endsWith('.$ext') && !fileName.toLowerCase().endsWith('.pdf')) {
      fileName = '$fileName.$ext';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CertificateModal(
        base64Data: base64,
        fileName: fileName,
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

      if (data['admin_remarks'] != null && (data['admin_remarks'] as String).isNotEmpty) ...[
        _InfoBanner(
          icon: rawStatus == 'resubmission_required' ? Icons.warning_amber_rounded : Icons.info_outline,
          color: rawStatus == 'resubmission_required' ? Tok.danger : Tok.warn,
          message: 'BFP Remarks: ${data['admin_remarks']}',
        ),
        const SizedBox(height: 12),
      ],

      if (rawStatus == 'pending_approval')
        _RequirementsChecklistCard(
          inspectionType: (data['inspection_type'] ?? 'Annual Fire Inspection').toString(),
          uploadedCount: 0,
        ),

      if (rawStatus == 'approved_waiting_requirements' || rawStatus == 'resubmission_required')
        _RequirementUpload(
          docId: docId,
          inspectionType: (data['inspection_type'] ?? 'Annual Fire Inspection').toString(),
          onUpload: onUploadRequirement,
          onSubmit: onSubmitRequirements,
        ),

      if (rawStatus == 'requirements_submitted')
        _RequirementSubmittedCard(
          docId: docId,
          inspectionType: (data['inspection_type'] ?? 'Annual Fire Inspection').toString(),
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
// Certificate Modal
// ===========================================================================
class CertificateModal extends StatelessWidget {
  final String base64Data;
  final String fileName;

  const CertificateModal({
    super.key,
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
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Center(
          child: Text(
            "Error: Invalid certificate data",
            style: Tok.body.copyWith(color: colors.textMid),
          ),
        ),
      );
    }

    // 2. Detect if it's a PDF (checking magic numbers or extension)
    bool isPdf = (bytes.length > 4 &&
            bytes[0] == 0x25 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x44 &&
            bytes[3] == 0x46) ||
        fileName.toLowerCase().endsWith('.pdf');

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.borderSoft)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    fileName.isNotEmpty ? fileName : "Certificate",
                    style: Tok.h3.copyWith(color: colors.textHi),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textMid),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Content - View PDF or Image
          Expanded(
            child: isPdf
                ? ClipRRect(
                    child: PdfPreview(
                      build: (format) => bytes,
                      useActions: false,
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      canDebug: false,
                      maxPageWidth: 700,
                      loadingWidget: Center(
                        child: CircularProgressIndicator(
                          color: colors.textLo,
                          strokeWidth: 2,
                        ),
                      ),
                      onError: (context, error) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            "Could not render PDF: $error",
                            style: Tok.bodySm.copyWith(color: colors.textMid),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  )
                : InteractiveViewer(
                    child: Center(
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                size: 48,
                                color: colors.textLo,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Unable to display image preview",
                                style:
                                    Tok.bodySm.copyWith(color: colors.textMid),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),

          // Footer / Download Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.borderSoft)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _downloadOrSaveFile(context, bytes, fileName),
                icon: const Icon(Icons.download_rounded),
                label: const Text("Download / Save"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Tok.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Tok.rSm),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadOrSaveFile(
      BuildContext context, Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      final base64Str = base64Encode(bytes);
      final ext = fileName.contains('.') ? fileName.split('.').last : 'pdf';
      final nameWithoutExt = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;
      downloadBase64File(base64Str, nameWithoutExt, ext);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading $fileName...'),
            backgroundColor: Tok.ok,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw 'Could not access storage directory';
      }

      final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filePath = '${directory.path}/$safeName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to Downloads: $safeName'),
            backgroundColor: Tok.ok,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () async {
                try {
                  await Printing.sharePdf(bytes: bytes, filename: safeName);
                } catch (_) {}
              },
            ),
          ),
        );
      }
    } catch (e) {
      try {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      } catch (e2) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed: $e'),
              backgroundColor: Tok.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
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
  final String inspectionType;
  final Future<void> Function(String) onUpload;
  final Future<void> Function(String) onSubmit;
  const _RequirementUpload({
    required this.docId,
    required this.inspectionType,
    required this.onUpload,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return StreamBuilder<QuerySnapshot>(
      stream: Provider.of<UserService>(context, listen: false)
          .streamRequestFiles(docId),
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
                'Upload up to 5 photos or files. Max 1 MB each.',
                style: Tok.caption.copyWith(color: colors.textLo),
              ),
              const SizedBox(height: 8),
              _RequirementsChecklistCard(
                inspectionType: inspectionType,
                uploadedCount: docs.length,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final base64Str = (data['base64'] ?? '').toString();
                    final fileName = (data['name'] ?? data['file_name'] ?? 'Document').toString();

                    Uint8List? bytes;
                    try {
                      if (base64Str.isNotEmpty) {
                        bytes = base64Decode(base64Str);
                      }
                    } catch (_) {}

                    final isPdf = bytes != null &&
                        bytes.length > 4 &&
                        bytes[0] == 0x25 &&
                        bytes[1] == 0x50 &&
                        bytes[2] == 0x44 &&
                        bytes[3] == 0x46;

                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (base64Str.isNotEmpty) {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => CertificateModal(
                                  base64Data: base64Str,
                                  fileName: fileName,
                                ),
                              );
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(Tok.rSm),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: colors.bg,
                                borderRadius: BorderRadius.circular(Tok.rSm),
                                border: Border.all(color: colors.borderSoft),
                              ),
                              child: (bytes != null && !isPdf)
                                  ? Image.memory(
                                      bytes,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _buildFileThumbnail(colors, isPdf, fileName),
                                    )
                                  : _buildFileThumbnail(colors, isPdf, fileName),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () async {
                              try {
                                await Provider.of<UserService>(context, listen: false)
                                    .deleteRequirementFile(docId: docId, fileId: doc.id);
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              color: colors.textMid,
                              size: 18,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Photo/File',
                              style: TextStyle(
                                fontSize: 8,
                                color: colors.textMid,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
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

  Widget _buildFileThumbnail(dynamic colors, bool isPdf, String fileName) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isPdf ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined,
          size: 20,
          color: isPdf ? Tok.danger : colors.textMid,
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            fileName,
            style: TextStyle(fontSize: 8, color: colors.textMid),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
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

// ===========================================================================
// Requirement Submitted Card
// ===========================================================================
class _RequirementSubmittedCard extends StatelessWidget {
  final String docId;
  final String inspectionType;

  const _RequirementSubmittedCard({
    required this.docId,
    required this.inspectionType,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: Provider.of<UserService>(context, listen: false)
          .streamRequestFiles(docId),
      builder: (context, snapshot) {
        final docs = snapshot.hasData ? snapshot.data!.docs : const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoBanner(
              icon: Icons.check_circle_outline,
              color: Tok.purple,
              message:
                  'Requirements uploaded (${docs.length} file${docs.length == 1 ? "" : "s"}). Waiting for an inspector to be assigned.',
            ),
            _RequirementsChecklistCard(
              inspectionType: inspectionType,
              uploadedCount: docs.length,
            ),
          ],
        );
      },
    );
  }
}

// ===========================================================================
// Requirements Checklist Card
// ===========================================================================
class _RequirementsChecklistCard extends StatelessWidget {
  final String inspectionType;
  final int uploadedCount;

  const _RequirementsChecklistCard({
    required this.inspectionType,
    required this.uploadedCount,
  });

  List<Map<String, String>> _getChecklist() {
    final type = inspectionType.toLowerCase();
    if (type.contains('annual')) {
      return [
        {
          'title': 'Previous FSIC',
          'desc': 'Copy of previous Fire Safety Inspection Certificate',
        },
        {
          'title': 'Business / Mayor\'s Permit',
          'desc': 'Copy of current Business or Mayor\'s Permit',
        },
        {
          'title': 'Fire Extinguisher Receipt / Certificate',
          'desc': 'Proof of active fire extinguisher maintenance/purchase',
        },
        {
          'title': 'Fire Safety Maintenance Report (FSMR)',
          'desc': 'Maintenance logs for building fire protection systems',
        },
      ];
    } else if (type.contains('business')) {
      return [
        {
          'title': 'DTI / SEC / CDA Registration',
          'desc': 'Certificate of business name registration',
        },
        {
          'title': 'Barangay Business Clearance',
          'desc': 'Current year Barangay clearance for business',
        },
        {
          'title': 'Occupancy Permit or Building Permit',
          'desc': 'Approved occupancy or building permit copy',
        },
        {
          'title': 'Fire Extinguisher Receipt / Safety Certificate',
          'desc': 'Proof of fire safety equipment compliance',
        },
      ];
    } else if (type.contains('installation') || type.contains('new')) {
      return [
        {
          'title': 'Approved Building & Fire Protection Plans',
          'desc': 'Architectural and fire protection engineering plans',
        },
        {
          'title': 'Building Official Endorsement',
          'desc': 'Official endorsement from City/Municipal Building Official',
        },
        {
          'title': 'Certificate of Completion',
          'desc': 'Signed completion certificate by licensed Engineer/Architect',
        },
        {
          'title': 'As-Built Electrical & Plumbing Plans',
          'desc': 'Certified as-built plans of the building/structure',
        },
      ];
    } else if (type.contains('drill')) {
      return [
        {
          'title': 'Fire Safety & Evacuation Plan (FSEP)',
          'desc': 'Documented evacuation procedure and safety plan',
        },
        {
          'title': 'Request Letter for Drill Supervision',
          'desc': 'Formal request letter addressed to Fire Marshal',
        },
        {
          'title': 'Roster of Safety Officers & Participants',
          'desc': 'List of emergency response team members',
        },
        {
          'title': 'Establishment Floor Plan / Evacuation Route',
          'desc': 'Diagram showing exit points and assembly areas',
        },
      ];
    } else {
      return [
        {
          'title': 'Valid Government-Issued ID',
          'desc': 'Proof of identity of applicant or representative',
        },
        {
          'title': 'Proof of Property Ownership / Lease',
          'desc': 'Title, tax declaration, or lease agreement copy',
        },
        {
          'title': 'Barangay Clearance',
          'desc': 'Clearance from local barangay',
        },
        {
          'title': 'Fire Extinguisher Receipt / Certificate',
          'desc': 'Proof of fire safety equipment',
        },
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = _getChecklist();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(Tok.rSm),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, size: 18, color: Tok.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Required Documents Checklist',
                  style: Tok.h3.copyWith(color: colors.textHi, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (uploadedCount >= items.length ? Tok.ok : Tok.warn)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Tok.rSm),
                ),
                child: Text(
                  '$uploadedCount / ${items.length} Submitted',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: uploadedCount >= items.length ? Tok.ok : Tok.warn,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Checklist of requirements for $inspectionType:',
            style: Tok.caption.copyWith(color: colors.textLo, fontSize: 11),
          ),
          const SizedBox(height: 10),
          ...List.generate(items.length, (idx) {
            final item = items[idx];
            final isDone = idx < uploadedCount;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 16,
                    color: isDone ? Tok.ok : colors.textLo,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${idx + 1}. ${item['title']!}',
                          style: Tok.bodySm.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.textHi,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        Text(
                          item['desc']!,
                          style: Tok.caption
                              .copyWith(color: colors.textLo, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}