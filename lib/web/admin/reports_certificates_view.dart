import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import '../../services/web_helper.dart';
import '../../services/textbee_service.dart';
import 'admin_theme.dart';

class ReportsCertificatesView extends StatefulWidget {
  const ReportsCertificatesView({super.key});

  @override
  State<ReportsCertificatesView> createState() =>
      _ReportsCertificatesViewState();
}

class _ReportsCertificatesViewState extends State<ReportsCertificatesView> {
  String? _userRole;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!mounted) return;
    setState(() {
      _userRole = (doc.data()?['role'] ?? 'User').toString().toLowerCase();
    });
  }

  bool get isClerk =>
      _userRole == 'clerk/encoder' ||
          _userRole == 'clerk' ||
          _userRole == 'encoder';

  bool get isMarshal =>
      _userRole == 'fire marshal' ||
          _userRole == 'firemarshal' ||
          _userRole == 'firemarshall' ||
          _userRole == 'admin';

  @override
  Widget build(BuildContext context) {
    if (_userRole == null) {
      return Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Tok.textLo,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Tok.surface,
                    borderRadius: BorderRadius.circular(Tok.rMd),
                    border: Border.all(color: Tok.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: Tok.body,
                    decoration: InputDecoration(
                      hintText: 'Search by property or owner...',
                      hintStyle: Tok.bodySm.copyWith(color: Tok.textLo),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: Tok.textLo,
                      ),
                      border: InputBorder.none,
                      contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _searchController.clear(),
                  child: Text(
                    'Clear',
                    style: TextStyle(color: Tok.textLo, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          if (isClerk) ...[
            const _SectionHeading(
              title: 'Inspection registry',
              subtitle:
              'Upload the certificate draft for any completed inspection. The Fire Marshal reviews and releases it to the client.',
            ),
            const SizedBox(height: 12),
            _ClerkRegistry(
              onUpload: _uploadCertificate,
              searchQuery: _searchController.text,
            ),
            const SizedBox(height: 32),
          ],

          if (isMarshal) ...[
            const _SectionHeading(
              title: 'Awaiting issuance',
              subtitle:
              'Drafts uploaded by clerks. Review the file, verify requirements and inspection photos, then approve and send.',
            ),
            const SizedBox(height: 12),
            _MarshalQueue(
              onReview: _viewCertificate,
              onIssue: _issueCertificate,
              onViewUserFiles: _viewUserFiles,
              onViewInspectionPhoto: (b64) => _viewCertificate({
                'certificate_base64': b64,
                'certificate_extension': 'jpg',
              }),
              searchQuery: _searchController.text,
            ),
            const SizedBox(height: 32),
          ],

          const _SectionHeading(
            title: 'Recently issued',
            subtitle:
            'Certificates the Fire Marshal has officially released. Click any record to open the full audit trail.',
          ),
          const SizedBox(height: 12),
          _RecentlyIssued(
            onOpen: _showIssuedDetailDialog,
            searchQuery: _searchController.text,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // ACTIONS (behavior unchanged)
  // ---------------------------------------------------------------------
  Future<void> _issueCertificate(String docId) async {
    final docRef =
    FirebaseFirestore.instance.collection('inspection_requests').doc(docId);
    final doc = await docRef.get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;

    DateTime selectedDate = DateTime.now().add(const Duration(days: 365));

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Dialog(
          backgroundColor: Tok.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tok.rLg),
            side: BorderSide(color: Tok.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Issue Fire Safety Certificate', style: Tok.h2),
                  const SizedBox(height: 6),
                  Text(
                    'Set the validity and expiration date for ${(data['property_name'] ?? 'property')}.',
                    style: Tok.bodySm.copyWith(color: Tok.textLo),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Tok.bg,
                      borderRadius: BorderRadius.circular(Tok.rMd),
                      border: Border.all(color: Tok.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_outlined, size: 18, color: Tok.info),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('EXPIRATION DATE', style: Tok.label),
                              const SizedBox(height: 2),
                              Text(
                                '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                                style: Tok.body.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: dialogCtx,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 3650)),
                            );
                            if (picked != null) {
                              setDialogState(() => selectedDate = picked);
                            }
                          },
                          child: const Text('Change Date'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: Text('Cancel', style: TextStyle(color: Tok.textMid)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Issue Certificate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Tok.brand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Tok.rMd),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final expDateStr =
        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

    await docRef.update({
      'certificate_status': 'issued',
      'issued_at': FieldValue.serverTimestamp(),
      'expiration_date': Timestamp.fromDate(selectedDate),
    });

    await FirebaseFirestore.instance.collection('notifications').add({
      'uid': data['uid'],
      'title': 'Certificate Issued',
      'message':
      'Your Fire Safety Clearance for ${data['property_name']} has been officially issued. Valid until $expDateStr.',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });

    if (data['phone'] != null) {
      _sendSMS(
        data['phone'],
        "Hello! Your Fire Safety Certificate for ${data['property_name']} has been issued (Valid until $expDateStr). You can now download it from the PyraCheck app.",
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Certificate issued (Valid until $expDateStr)'),
          backgroundColor: Tok.ok,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendSMS(String phoneNumber, String message) async {
    final success = await TextbeeService.sendSMS(phoneNumber, message);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'SMS sent' : 'SMS failed — check logs'),
          backgroundColor: success ? Tok.ok : Tok.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _uploadCertificate(String docId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    try {
      if (bytes.length > 750000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File too large. Maximum 750 KB.'),
              backgroundColor: Tok.warn,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final base64String = base64Encode(bytes);
      final extension = file.extension ?? 'pdf';

      await FirebaseFirestore.instance
          .collection('inspection_requests')
          .doc(docId)
          .update({
        'certificate_base64': base64String,
        'certificate_extension': extension,
        'certificate_filename': file.name,
        'certificate_status': 'pending_review',
        'certificate_issued_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
            Text('Draft uploaded — sent to Fire Marshal for review.'),
            backgroundColor: Tok.ok,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Tok.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _viewCertificate(Map<String, dynamic> data) {
    final base64 = data['certificate_base64'] as String?;
    final ext = (data['certificate_extension'] ?? 'jpg').toString();
    if (base64 == null) return;

    if (ext.toLowerCase() == 'pdf') {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening PDF in a new tab — allow popups.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        openBase64InNewTab(base64, ext);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF viewing is optimized for the web build.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      _showMediaDialog(
        title: 'Certificate preview',
        subtitle: (data['certificate_filename'] ?? 'Image').toString(),
        items: [
          _MediaItem(
            name: (data['certificate_filename'] ?? 'image').toString(),
            base64: base64,
          ),
        ],
      );
    }
  }

  void _viewUserFiles(BuildContext context, String docId) {
    _showMediaDialog(
      title: 'Client requirements',
      subtitle: 'Files uploaded by the property owner',
      stream: FirebaseFirestore.instance
          .collection('inspection_requests')
          .doc(docId)
          .collection('files')
          .snapshots(),
      emptyLabel: 'No requirement files were uploaded for this request.',
    );
  }

  void _showIssuedDetailDialog(
      BuildContext context, String docId, Map<String, dynamic> data) {
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
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (data['property_name'] ?? 'Audit record')
                                .toString(),
                            style: TextStyle(
                              fontFamily: Tok.stack,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Tok.textHi,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Tok.ok,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Issued',
                                style: Tok.bodySm.copyWith(
                                  color: Tok.textMid,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '·',
                                style:
                                Tok.bodySm.copyWith(color: Tok.textLo),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                docId,
                                style: Tok.bodySm.copyWith(
                                  color: Tok.textLo,
                                  fontSize: 11,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Tok.textMid,
                      ),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Tok.borderSoft),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Timeline(data: data),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, c) {
                          final wide = c.maxWidth >= 900;
                          final client = _AuditColumn(
                            title: 'Client submissions',
                            meta:
                            'Owner · ${data['full_name'] ?? data['email'] ?? '—'}',
                            docId: docId,
                            subcollection: 'files',
                            emptyLabel: 'No requirement files found.',
                          );
                          final inspector = _AuditColumn(
                            title: 'Inspection proof',
                            meta:
                            'Inspector · ${data['inspector_name'] ?? '—'}',
                            docId: docId,
                            subcollection: 'evidence',
                            emptyLabel: 'No evidence photos found.',
                          );
                          final validation = _ValidationColumn(
                            data: data,
                            onView: () => _viewCertificate(data),
                          );

                          if (wide) {
                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: client),
                                  const SizedBox(width: 20),
                                  Expanded(flex: 3, child: inspector),
                                  const SizedBox(width: 20),
                                  Expanded(flex: 2, child: validation),
                                ],
                              ),
                            );
                          }
                          return Column(
                            children: [
                              client,
                              const SizedBox(height: 20),
                              inspector,
                              const SizedBox(height: 20),
                              validation,
                            ],
                          );
                        },
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

  void _showMediaDialog({
    required String title,
    String? subtitle,
    Stream<QuerySnapshot>? stream,
    List<_MediaItem>? items,
    String? emptyLabel,
  }) {
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
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 640),
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
                          Text(title, style: Tok.h2),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: Tok.bodySm.copyWith(
                                color: Tok.textLo,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Tok.textMid,
                      ),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Tok.borderSoft),
              Expanded(
                child: items != null
                    ? _MediaGrid(items: items)
                    : StreamBuilder<QuerySnapshot>(
                  stream: stream!,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Tok.textLo,
                          ),
                        ),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return EmptyState(
                        icon: Icons.image_outlined,
                        label: emptyLabel ?? 'No files were found.',
                      );
                    }
                    final list = docs.map((d) {
                      final map = d.data() as Map<String, dynamic>;
                      return _MediaItem(
                        name: (map['name'] ?? 'image').toString(),
                        base64: map['base64'].toString(),
                      );
                    }).toList();
                    return _MediaGrid(items: list);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Tok.h2),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Tok.bodySm.copyWith(color: Tok.textLo, fontSize: 12),
        ),
      ],
    );
  }
}

class _StatusTag extends StatelessWidget {
  final String status;
  const _StatusTag({required this.status});

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

class _RowActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback onPressed;
  const _RowActionButton({
    required this.label,
    required this.icon,
    this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Tok.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 30),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tok.rMd)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _GhostIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const _GhostIconButton({
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

class _ClerkRegistry extends StatelessWidget {
  final Future<void> Function(String docId) onUpload;
  final String searchQuery;
  const _ClerkRegistry({required this.onUpload, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inspection_requests')
          .orderBy('requested_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Panel(
            title: 'Registry',
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Tok.textLo,
                ),
              ),
            ),
          );
        }
        var docs = snapshot.data!.docs;

        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final property =
            (data['property_name'] ?? '').toString().toLowerCase();
            final owner = (data['full_name'] ?? data['email'] ?? '')
                .toString()
                .toLowerCase();
            return property.contains(q) || owner.contains(q);
          }).toList();
        }

        return Panel(
          title: 'All inspections',
          padded: false,
          child: Column(
            children: [
              Container(
                color: Tok.surfaceAlt,
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text('PROPERTY / OWNER', style: Tok.label),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('PURPOSE', style: Tok.label),
                    ),
                    SizedBox(
                      width: 130,
                      child: Text('STATUS', style: Tok.label),
                    ),
                    SizedBox(
                      width: 200,
                      child: Text('CERTIFICATE', style: Tok.label),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Tok.borderSoft),
              docs.isEmpty
                  ? const EmptyState(
                icon: Icons.folder_outlined,
                label: 'No matching records',
              )
                  : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: docs.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Tok.borderSoft),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _RegistryRow(
                    data: data,
                    onUpload: () => onUpload(doc.id),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RegistryRow extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onUpload;
  const _RegistryRow({required this.data, required this.onUpload});

  @override
  State<_RegistryRow> createState() => _RegistryRowState();
}

class _RegistryRowState extends State<_RegistryRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final status = (data['status'] ?? 'pending_approval').toString();
    final hasCert = data['certificate_base64'] != null;
    final certStatus = (data['certificate_status'] ?? '').toString();

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        color:
        _hover ? Tok.surfaceAlt.withValues(alpha: 0.55) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (data['property_name'] ?? 'Untitled').toString(),
                    style: Tok.body.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    (data['full_name'] ?? data['email'] ?? '—').toString(),
                    style:
                    Tok.bodySm.copyWith(color: Tok.textLo, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                (data['inspection_type'] ?? '—').toString(),
                style: Tok.bodySm.copyWith(color: Tok.textMid),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 130,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StatusTag(status: status),
              ),
            ),
            SizedBox(
              width: 200,
              child: Row(
                children: [
                  _CertIndicator(hasCert: hasCert, status: certStatus),
                  const SizedBox(width: 12),
                  _RowActionButton(
                    label: hasCert ? 'Update' : 'Upload',
                    icon: hasCert
                        ? Icons.published_with_changes_outlined
                        : Icons.upload_file_outlined,
                    onPressed: widget.onUpload,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CertIndicator extends StatelessWidget {
  final bool hasCert;
  final String status;
  const _CertIndicator({required this.hasCert, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'issued' when hasCert => ('Issued', Tok.ok),
      'pending_review' when hasCert => ('In review', Tok.warn),
      _ when hasCert => ('Draft', Tok.textMid),
      _ => ('None', Tok.textLo),
    };
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
          style: Tok.bodySm.copyWith(color: Tok.textMid, fontSize: 11),
        ),
      ],
    );
  }
}

class _MarshalQueue extends StatelessWidget {
  final void Function(Map<String, dynamic> data) onReview;
  final Future<void> Function(String docId) onIssue;
  final void Function(BuildContext context, String docId) onViewUserFiles;
  final void Function(String base64) onViewInspectionPhoto;
  final String searchQuery;

  const _MarshalQueue({
    required this.onReview,
    required this.onIssue,
    required this.onViewUserFiles,
    required this.onViewInspectionPhoto,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inspection_requests')
          .where('certificate_status', isEqualTo: 'pending_review')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Panel(
            title: 'Queue',
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Tok.textLo,
                ),
              ),
            ),
          );
        }
        var docs = snapshot.data!.docs;

        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final property =
            (data['property_name'] ?? '').toString().toLowerCase();
            final owner = (data['full_name'] ?? data['email'] ?? '')
                .toString()
                .toLowerCase();
            return property.contains(q) || owner.contains(q);
          }).toList();
        }

        return Panel(
          title: 'Pending drafts',
          padded: false,
          child: Column(
            children: [
              Container(
                color: Tok.surfaceAlt,
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    const SizedBox(width: 46), // Thumbnail space
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: Text('PROPERTY', style: Tok.label),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('DRAFT FILE', style: Tok.label),
                    ),
                    SizedBox(
                      width: 320,
                      child: Text('ACTIONS', style: Tok.label),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Tok.borderSoft),
              docs.isEmpty
                  ? const EmptyState(
                icon: Icons.mark_email_unread_outlined,
                label: 'Nothing awaiting review',
              )
                  : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: docs.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Tok.borderSoft),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _QueueRow(
                    data: data,
                    onReview: () => onReview(data),
                    onIssue: () => onIssue(doc.id),
                    onViewUserFiles: () =>
                        onViewUserFiles(context, doc.id),
                    onViewInspectionPhoto:
                    data['evidence_base64'] != null
                        ? () => onViewInspectionPhoto(
                      data['evidence_base64'] as String,
                    )
                        : null,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QueueRow extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onReview;
  final VoidCallback onIssue;
  final VoidCallback onViewUserFiles;
  final VoidCallback? onViewInspectionPhoto;

  const _QueueRow({
    required this.data,
    required this.onReview,
    required this.onIssue,
    required this.onViewUserFiles,
    required this.onViewInspectionPhoto,
  });

  @override
  State<_QueueRow> createState() => _QueueRowState();
}

class _QueueRowState extends State<_QueueRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final ext =
    (data['certificate_extension'] ?? 'img').toString().toLowerCase();
    final isPdf = ext == 'pdf';
    final fileName = (data['certificate_filename'] ?? 'Draft file').toString();
    final property = (data['property_name'] ?? 'Untitled').toString();
    final owner = (data['full_name'] ?? data['email'] ?? '—').toString();
    final phone = (data['phone'] ?? '').toString();

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        color:
        _hover ? Tok.surfaceAlt.withValues(alpha: 0.55) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail
            SizedBox(
              width: 46,
              height: 46,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Tok.rSm),
                child: isPdf || data['certificate_base64'] == null
                    ? Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Tok.surfaceAlt,
                    border: Border.all(color: Tok.border),
                    borderRadius: BorderRadius.circular(Tok.rSm),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 18,
                    color: Tok.textMid,
                  ),
                )
                    : Image.memory(
                  base64Decode(data['certificate_base64'] as String),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Property + owner + phone
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property,
                    style: Tok.body.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    owner,
                    style:
                    Tok.bodySm.copyWith(color: Tok.textLo, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      phone,
                      style: Tok.bodySm.copyWith(
                        color: Tok.textLo,
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Draft file
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: Tok.bodySm.copyWith(color: Tok.textMid),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    ext.toUpperCase(),
                    style: Tok.bodySm.copyWith(
                      color: Tok.textLo,
                      fontSize: 11,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            SizedBox(
              width: 320,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _GhostIconButton(
                    icon: Icons.folder_shared_outlined,
                    tooltip: 'Client requirements',
                    onPressed: widget.onViewUserFiles,
                  ),
                  if (widget.onViewInspectionPhoto != null) ...[
                    const SizedBox(width: 6),
                    _GhostIconButton(
                      icon: Icons.image_search_outlined,
                      tooltip: 'Inspection photo',
                      onPressed: widget.onViewInspectionPhoto!,
                    ),
                  ],
                  const SizedBox(width: 12),
                  _RowActionButton(
                    label: 'Review',
                    icon: Icons.visibility_outlined,
                    color: Tok.info,
                    onPressed: widget.onReview,
                  ),
                  const SizedBox(width: 8),
                  _RowActionButton(
                    label: 'Issue',
                    icon: Icons.verified_user_outlined,
                    color: Tok.brand,
                    onPressed: widget.onIssue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentlyIssued extends StatelessWidget {
  final void Function(BuildContext, String, Map<String, dynamic>) onOpen;
  final String searchQuery;
  const _RecentlyIssued({required this.onOpen, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inspection_requests')
          .where('certificate_status', isEqualTo: 'issued')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const EmptyState(
            icon: Icons.error_outline_rounded,
            label: 'Failed to load issued records',
          );
        }
        if (!snapshot.hasData) {
          return Center(
            child: SizedBox(
              height: 96,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Tok.textLo,
                  ),
                ),
              ),
            ),
          );
        }

        var docs = snapshot.data!.docs;

        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final property =
            (data['property_name'] ?? '').toString().toLowerCase();
            final owner = (data['full_name'] ?? data['email'] ?? '')
                .toString()
                .toLowerCase();
            return property.contains(q) || owner.contains(q);
          }).toList();
        }

        final sorted = docs.toList()
          ..sort((a, b) {
            final at = (a.data() as Map)['issued_at'] as Timestamp?;
            final bt = (b.data() as Map)['issued_at'] as Timestamp?;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });

        if (sorted.isEmpty) {
          return const EmptyState(
            icon: Icons.verified_outlined,
            label: 'No certificates issued yet',
          );
        }

        return SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final doc = sorted[index];
              final data = doc.data() as Map<String, dynamic>;
              return _IssuedCard(
                data: data,
                onTap: () => onOpen(context, doc.id, data),
              );
            },
          ),
        );
      },
    );
  }
}

class _IssuedCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _IssuedCard({required this.data, required this.onTap});

  @override
  State<_IssuedCard> createState() => _IssuedCardState();
}

class _IssuedCardState extends State<_IssuedCard> {
  bool _hover = false;

  String _fmtDate(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final d = ts.toDate();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final expTs = data['expiration_date'] as Timestamp?;
    final isExpired = expTs != null && expTs.toDate().isBefore(DateTime.now());
    final statusColor = isExpired ? Tok.danger : Tok.ok;
    final statusText = isExpired ? 'Expired' : 'Valid';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: 270,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _hover ? Tok.surfaceAlt : Tok.surface,
            borderRadius: BorderRadius.circular(Tok.rLg),
            border: Border.all(
              color: _hover ? Tok.border : Tok.borderSoft,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('Issued · $statusText', style: Tok.label.copyWith(color: statusColor)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                (data['property_name'] ?? 'Untitled').toString(),
                style: Tok.body.copyWith(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Issued: ${_fmtDate(data['issued_at'])}',
                    style: Tok.bodySm.copyWith(
                      color: Tok.textLo,
                      fontSize: 10,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    'Expires: ${_fmtDate(data['expiration_date'])}',
                    style: Tok.bodySm.copyWith(
                      color: isExpired ? Tok.danger : Tok.textMid,
                      fontSize: 10,
                      fontWeight: isExpired ? FontWeight.bold : FontWeight.normal,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
}

class _Timeline extends StatelessWidget {
  final Map<String, dynamic> data;
  const _Timeline({required this.data});

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

  String _fmt(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final d = ts.toDate();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final done = timestamp is Timestamp;
    final color = done ? Tok.ok : Tok.textLo;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: done ? Tok.ok : Tok.bg,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: color, width: 1),
                  ),
                ),
                const SizedBox(width: 8),
                Text(label, style: Tok.label.copyWith(color: Tok.textMid)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _fmt(timestamp),
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

class _AuditColumn extends StatelessWidget {
  final String title;
  final String meta;
  final String docId;
  final String subcollection;
  final String emptyLabel;

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
        Text(
          meta,
          style: Tok.bodySm.copyWith(color: Tok.textLo, fontSize: 11),
        ),
        const SizedBox(height: 12),
        FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('inspection_requests')
              .doc(docId)
              .collection(subcollection)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Tok.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Tok.rSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_person_outlined,
                      size: 16,
                      color: Tok.danger,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Access denied to "$subcollection".',
                      style: Tok.bodySm.copyWith(
                        color: Tok.danger,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Tok.textLo,
                  ),
                ),
              );
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Tok.bg,
                  borderRadius: BorderRadius.circular(Tok.rMd),
                  border: Border.all(color: Tok.borderSoft),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: Tok.textLo,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        emptyLabel,
                        style: Tok.bodySm.copyWith(
                          color: Tok.textLo,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final base64 = data['base64'] as String?;
                final detections = (data['detections'] as List?) ?? const [];
                if (base64 == null || base64.isEmpty) {
                  return const SizedBox.shrink();
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
                                    Text('Inspection Evidence Photo', style: Tok.h2),
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
                                                    child: Text(
                                                      '🤖 $cls ${pct.isNotEmpty ? "($pct)" : ""}',
                                                      style: TextStyle(
                                                        color: Tok.textHi,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w500,
                                                      ),
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
                            color: Tok.surfaceAlt,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Tok.textLo,
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
                            child: Text(
                              '🤖 ${detections.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
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

class _ValidationColumn extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onView;
  const _ValidationColumn({required this.data, required this.onView});

  String _fmtDate(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final d = ts.toDate();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sig = data['client_signature_base64'] as String?;
    final hasCert = data['certificate_base64'] != null;
    final expTs = data['expiration_date'] as Timestamp?;
    final isExpired = expTs != null && expTs.toDate().isBefore(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Validation', style: Tok.h2),
        const SizedBox(height: 2),
        Text(
          'Final authorizations',
          style: Tok.bodySm.copyWith(color: Tok.textLo, fontSize: 11),
        ),
        const SizedBox(height: 12),
        if (expTs != null) ...[
          Text('EXPIRATION DATE', style: Tok.label),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (isExpired ? Tok.danger : Tok.ok).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Tok.rSm),
              border: Border.all(
                color: (isExpired ? Tok.danger : Tok.ok).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isExpired ? Icons.event_busy_rounded : Icons.verified_user_outlined,
                  size: 14,
                  color: isExpired ? Tok.danger : Tok.ok,
                ),
                const SizedBox(width: 6),
                Text(
                  isExpired ? 'Expired on ${_fmtDate(expTs)}' : 'Valid until ${_fmtDate(expTs)}',
                  style: TextStyle(
                    color: isExpired ? Tok.danger : Tok.ok,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (sig != null) ...[
          Text('CLIENT SIGNATURE', style: Tok.label),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Tok.rMd),
            ),
            child: Image.memory(base64Decode(sig), height: 72),
          ),
          const SizedBox(height: 16),
        ],
        Text('OFFICIAL DOCUMENT', style: Tok.label),
        const SizedBox(height: 8),
        if (hasCert)
          _RowActionButton(
            label: 'View certificate',
            icon: Icons.description_outlined,
            onPressed: onView,
          )
        else
          Text(
            'No certificate attached.',
            style: Tok.bodySm.copyWith(color: Tok.textLo, fontSize: 11),
          ),
      ],
    );
  }
}

class _MediaItem {
  final String name;
  final String base64;
  const _MediaItem({required this.name, required this.base64});
}

class _MediaGrid extends StatelessWidget {
  final List<_MediaItem> items;
  const _MediaGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(Tok.rMd),
          child: Container(
            decoration: BoxDecoration(
              color: Tok.bg,
              borderRadius: BorderRadius.circular(Tok.rMd),
              border: Border.all(color: Tok.border),
              image: DecorationImage(
                image: MemoryImage(base64Decode(items[index].base64)),
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }
}