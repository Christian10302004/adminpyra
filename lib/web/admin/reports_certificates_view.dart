import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img_lib;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
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
          child: CircularProgressIndicator(strokeWidth: 2, color: Tok.textLo),
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
              onEdit: _editCertificate,
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
              onViewInspectionPhoto: _viewInspectionPhotos,
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
    final docRef = FirebaseFirestore.instance
        .collection('inspection_requests')
        .doc(docId);
    final doc = await docRef.get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;

    DateTime selectedDate = DateTime.now().add(const Duration(days: 365));

    if (!mounted) return;
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
                                style: Tok.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
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
                              lastDate: DateTime.now().add(
                                const Duration(days: 3650),
                              ),
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
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Tok.textMid),
                        ),
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

  Future<void> _uploadCertificate(
    String docId, [
    Map<String, dynamic>? data,
  ]) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read the selected PDF file.'),
          ),
        );
      }
      return;
    }
    try {
      await _openCertificateEditor(
        docId: docId,
        requestData: data ?? const {},
        fileBytes: bytes,
        fileName: file.name,
        fileExtension: file.extension ?? 'pdf',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open the selected certificate: $error'),
            backgroundColor: Tok.danger,
          ),
        );
      }
    }
  }

  Future<void> _editCertificate(String docId, Map<String, dynamic> data) async {
    final encodedFile = data['certificate_base64'] as String?;
    try {
      if (encodedFile == null || encodedFile.isEmpty) {
        throw StateError('There is no certificate file to edit.');
      }
      final bytes = base64Decode(encodedFile);
      final extension = (data['certificate_extension'] ?? 'pdf').toString();
      await _openCertificateEditor(
        docId: docId,
        requestData: data,
        fileBytes: bytes,
        fileName: (data['certificate_filename'] ?? 'FSIC_$docId.$extension')
            .toString(),
        fileExtension: extension,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open the existing certificate: $error'),
            backgroundColor: Tok.danger,
          ),
        );
      }
    }
  }

  Future<void> _openCertificateEditor({
    required String docId,
    required Map<String, dynamic> requestData,
    required Uint8List fileBytes,
    required String fileName,
    required String fileExtension,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => _CertificateEditorModal(
        docId: docId,
        requestData: requestData,
        fileBytes: fileBytes,
        fileName: fileName,
        fileExtension: fileExtension,
        onUploaded: () {
          setState(() {});
        },
      ),
    );
  }

  void _viewCertificate(Map<String, dynamic> data) {
    final base64 = data['certificate_base64'] as String?;
    final ext = (data['certificate_extension'] ?? 'jpg').toString();
    if (base64 == null || base64.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No certificate file is available.')),
      );
      return;
    }

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
      _showMediaPreview(
        _MediaItem(
          name: (data['certificate_filename'] ?? 'Image').toString(),
          base64: base64,
        ),
      );
    }
  }

  void _showMediaPreview(_MediaItem item) {
    showDialog(
      context: context,
      builder: (context) => _SingleMediaDialog(item: item),
    );
  }

  void _viewInspectionPhotos(
    BuildContext context,
    String docId, [
    Map<String, dynamic>? data,
  ]) {
    _showMediaDialog(
      title: 'Inspection photos',
      subtitle: 'Photos submitted by the inspector',
      stream: FirebaseFirestore.instance
          .collection('inspection_requests')
          .doc(docId)
          .collection('evidence')
          .snapshots(),
      primaryBase64: data?['evidence_base64'] as String?,
      emptyLabel: 'No inspection photos were uploaded for this request.',
      inspectorRemarks: data?['inspector_remarks'] as String?,
    );
  }

  void _viewUserFiles(
    BuildContext context,
    String docId, [
    Map<String, dynamic>? data,
  ]) {
    final certType = (data?['inspection_type'] ?? 'Annual Fire Inspection')
        .toString();
    _showMediaDialog(
      title: 'Client requirements',
      subtitle:
          'Files uploaded by property owner · Certificate Requested: $certType',
      inspectionType: certType,
      stream: FirebaseFirestore.instance
          .collection('inspection_requests')
          .doc(docId)
          .collection('files')
          .snapshots(),
      emptyLabel: 'No requirement files were uploaded for this request.',
    );
  }

  void _showIssuedDetailDialog(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
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
                                style: Tok.bodySm.copyWith(color: Tok.textLo),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                docId,
                                style: Tok.bodySm.copyWith(
                                  color: Tok.textLo,
                                  fontSize: 11,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
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
                            inspectorRemarks:
                                data['inspector_remarks'] as String?,
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
    String? inspectionType,
    Stream<QuerySnapshot>? stream,
    List<_MediaItem>? items,
    String? primaryBase64,
    String? emptyLabel,
    String? inspectorRemarks,
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
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 680),
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
                          if (snapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Could not load uploaded files: ${snapshot.error}',
                                  style: Tok.bodySm.copyWith(color: Tok.danger),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }
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
                          final list = docs
                              .map((d) {
                                final map = d.data() as Map<String, dynamic>;
                                final base64 = (map['base64'] ?? '').toString();
                                return _MediaItem(
                                  name: (map['name'] ?? '').toString(),
                                  base64: base64,
                                );
                              })
                              .where((item) => item.base64.isNotEmpty)
                              .toList();
                          if (primaryBase64 != null &&
                              primaryBase64.trim().isNotEmpty &&
                              !list.any(
                                (item) => item.base64 == primaryBase64,
                              )) {
                            list.insert(
                              0,
                              _MediaItem(
                                name: 'Inspection photo',
                                base64: primaryBase64,
                              ),
                            );
                          }
                          for (var i = 0; i < list.length; i++) {
                            if (list[i].name.isEmpty) {
                              list[i] = _MediaItem(
                                name: 'Inspection photo ${i + 1}',
                                base64: list[i].base64,
                              );
                            }
                          }

                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (inspectionType != null)
                                  WebRequirementsChecklist(
                                    inspectionType: inspectionType,
                                    uploadedCount: list.length,
                                  ),
                                if (inspectorRemarks != null &&
                                    inspectorRemarks.trim().isNotEmpty) ...[
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Tok.bg,
                                      borderRadius:
                                          BorderRadius.circular(Tok.rMd),
                                      border: Border.all(color: Tok.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.notes_rounded,
                                              size: 16,
                                              color: Tok.brand,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Inspector Remarks',
                                              style: TextStyle(
                                                color: Tok.textHi,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          inspectorRemarks,
                                          style: Tok.bodySm.copyWith(
                                            color: Tok.textHi,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (list.isEmpty)
                                  EmptyState(
                                    icon: Icons.image_outlined,
                                    label: emptyLabel ?? 'No files were found.',
                                  )
                                else
                                  _MediaGrid(items: list, shrinkWrap: true),
                              ],
                            ),
                          );
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tok.rMd),
        ),
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
  final Future<void> Function(String docId, [Map<String, dynamic>? data])
  onUpload;
  final Future<void> Function(String docId, Map<String, dynamic> data) onEdit;
  final String searchQuery;
  const _ClerkRegistry({
    required this.onUpload,
    required this.onEdit,
    required this.searchQuery,
  });

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
            final property = (data['property_name'] ?? '')
                .toString()
                .toLowerCase();
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text('PROPERTY / OWNER', style: Tok.label),
                    ),
                    Expanded(flex: 2, child: Text('PURPOSE', style: Tok.label)),
                    SizedBox(
                      width: 130,
                      child: Text('STATUS', style: Tok.label),
                    ),
                    SizedBox(
                      width: 250,
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
                          onUpload: () => onUpload(doc.id, data),
                          onEdit: () => onEdit(doc.id, data),
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
  final VoidCallback onEdit;
  const _RegistryRow({
    required this.data,
    required this.onUpload,
    required this.onEdit,
  });

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
        color: _hover
            ? Tok.surfaceAlt.withValues(alpha: 0.55)
            : Colors.transparent,
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
                    style: Tok.bodySm.copyWith(color: Tok.textLo, fontSize: 11),
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
              width: 250,
              child: Row(
                children: [
                  _CertIndicator(hasCert: hasCert, status: certStatus),
                  const SizedBox(width: 8),
                  if (hasCert) ...[
                    _RowActionButton(
                      label: 'Edit PDF',
                      icon: Icons.edit_note_rounded,
                      onPressed: widget.onEdit,
                    ),
                    const SizedBox(width: 6),
                    _GhostIconButton(
                      icon: Icons.upload_file_outlined,
                      tooltip: 'Replace PDF',
                      onPressed: widget.onUpload,
                    ),
                  ] else
                    _RowActionButton(
                      label: 'Upload PDF',
                      icon: Icons.upload_file_outlined,
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
  final void Function(
    BuildContext context,
    String docId, [
    Map<String, dynamic>? data,
  ])
  onViewUserFiles;
  final void Function(
    BuildContext context,
    String docId, [
    Map<String, dynamic>? data,
  ])
  onViewInspectionPhoto;
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
            final property = (data['property_name'] ?? '')
                .toString()
                .toLowerCase();
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
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
                              onViewUserFiles(context, doc.id, data),
                          onViewInspectionPhoto: () =>
                              onViewInspectionPhoto(context, doc.id, data),
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
    final ext = (data['certificate_extension'] ?? 'img')
        .toString()
        .toLowerCase();
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
        color: _hover
            ? Tok.surfaceAlt.withValues(alpha: 0.55)
            : Colors.transparent,
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
                    style: Tok.bodySm.copyWith(color: Tok.textLo, fontSize: 11),
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
            final property = (data['property_name'] ?? '')
                .toString()
                .toLowerCase();
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
            border: Border.all(color: _hover ? Tok.border : Tok.borderSoft),
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
                  Text(
                    'Issued · $statusText',
                    style: Tok.label.copyWith(color: statusColor),
                  ),
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
                      fontWeight: isExpired
                          ? FontWeight.bold
                          : FontWeight.normal,
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
  final String? inspectorRemarks;

  const _AuditColumn({
    required this.title,
    required this.meta,
    required this.docId,
    required this.subcollection,
    required this.emptyLabel,
    this.inspectorRemarks,
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
        if (subcollection == 'evidence' &&
            inspectorRemarks != null &&
            inspectorRemarks!.trim().isNotEmpty) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
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
                    Icon(Icons.notes_rounded, size: 14, color: Tok.brand),
                    const SizedBox(width: 4),
                    Text(
                      'Inspector Remarks',
                      style: TextStyle(
                        color: Tok.textHi,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  inspectorRemarks!,
                  style: Tok.bodySm.copyWith(color: Tok.textHi, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
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
                final name =
                    (data['name'] ??
                            data['file_name'] ??
                            'Requirement Document')
                        .toString();
                final detections = (data['detections'] as List?) ?? const [];
                final docRemarks = (data['remarks'] ?? '').toString();
                final displayRemarks = docRemarks.isNotEmpty
                    ? docRemarks
                    : (inspectorRemarks ?? '');
                if (base64 == null || base64.isEmpty) {
                  return const SizedBox.shrink();
                }

                bool isPdf = name.toLowerCase().endsWith('.pdf');
                if (!isPdf) {
                  try {
                    final bytes = base64Decode(base64);
                    isPdf =
                        bytes.length > 4 &&
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
                          constraints: const BoxConstraints(
                            maxWidth: 750,
                            maxHeight: 680,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  16,
                                  12,
                                  16,
                                ),
                                child: Row(
                                  children: [
                                    Text(name, style: Tok.h2),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                      ),
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
                                            borderRadius: BorderRadius.circular(
                                              Tok.rMd,
                                            ),
                                            border: Border.all(
                                              color: Tok.border,
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.picture_as_pdf_rounded,
                                                size: 64,
                                                color: Tok.danger,
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                name,
                                                style: Tok.h2,
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'PDF Document',
                                                style: Tok.bodySm.copyWith(
                                                  color: Tok.textLo,
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                              Wrap(
                                                spacing: 12,
                                                runSpacing: 12,
                                                alignment: WrapAlignment.center,
                                                children: [
                                                  ElevatedButton.icon(
                                                    onPressed: () =>
                                                        openBase64InNewTab(
                                                          base64,
                                                          'pdf',
                                                        ),
                                                    icon: const Icon(
                                                      Icons.open_in_new_rounded,
                                                      size: 18,
                                                    ),
                                                    label: const Text(
                                                      'Open PDF in New Tab',
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Tok.brand,
                                                      foregroundColor:
                                                          Colors.white,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 20,
                                                            vertical: 12,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              Tok.rSm,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                  OutlinedButton.icon(
                                                    onPressed: () =>
                                                        downloadBase64File(
                                                          base64,
                                                          name.replaceAll(
                                                            '.pdf',
                                                            '',
                                                          ),
                                                          'pdf',
                                                        ),
                                                    icon: const Icon(
                                                      Icons.download_rounded,
                                                      size: 18,
                                                    ),
                                                    label: const Text(
                                                      'Download PDF',
                                                    ),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor:
                                                          Tok.textHi,
                                                      side: BorderSide(
                                                        color: Tok.border,
                                                      ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 20,
                                                            vertical: 12,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              Tok.rSm,
                                                            ),
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
                                          borderRadius: BorderRadius.circular(
                                            Tok.rMd,
                                          ),
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxHeight: 420,
                                            ),
                                            child: Image.memory(
                                              base64Decode(base64),
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      if (displayRemarks.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Tok.bg,
                                            borderRadius:
                                                BorderRadius.circular(
                                                  Tok.rMd,
                                                ),
                                            border: Border.all(
                                              color: Tok.border,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.notes_rounded,
                                                    size: 16,
                                                    color: Tok.brand,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Inspector Remarks',
                                                    style: TextStyle(
                                                      color: Tok.textHi,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                displayRemarks,
                                                style: Tok.bodySm.copyWith(
                                                  color: Tok.textHi,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (detections.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Tok.bg,
                                            borderRadius: BorderRadius.circular(
                                              Tok.rMd,
                                            ),
                                            border: Border.all(
                                              color: Tok.border,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.psychology_outlined,
                                                    size: 16,
                                                    color: Tok.info,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Roboflow AI Identified Safety Equipment',
                                                    style: TextStyle(
                                                      color: Tok.textHi,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: detections.map((d) {
                                                  final cls =
                                                      (d['class'] ??
                                                              'Equipment')
                                                          .toString();
                                                  final pct =
                                                      (d['confidence_pct'] ??
                                                              '')
                                                          .toString();
                                                  return Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Tok.info
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            Tok.rSm,
                                                          ),
                                                      border: Border.all(
                                                        color: Tok.info
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .smart_toy_outlined,
                                                          size: 12,
                                                          color: Tok.info,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          '$cls ${pct.isNotEmpty ? "($pct)" : ""}',
                                                          style: TextStyle(
                                                            color: Tok.textHi,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w500,
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
                              Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 36,
                                color: Tok.danger,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Tok.textHi,
                                  fontWeight: FontWeight.w500,
                                ),
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
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 120,
                                  height: 120,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Tok.bg,
                                    borderRadius: BorderRadius.circular(
                                      Tok.rMd,
                                    ),
                                    border: Border.all(color: Tok.border),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.picture_as_pdf_rounded,
                                        size: 36,
                                        color: Tok.danger,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Tok.textHi,
                                        ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xB3000000),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.smart_toy_outlined,
                                  size: 11,
                                  color: Colors.white,
                                ),
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
                  isExpired
                      ? Icons.event_busy_rounded
                      : Icons.verified_user_outlined,
                  size: 14,
                  color: isExpired ? Tok.danger : Tok.ok,
                ),
                const SizedBox(width: 6),
                Text(
                  isExpired
                      ? 'Expired on ${_fmtDate(expTs)}'
                      : 'Valid until ${_fmtDate(expTs)}',
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
  final bool shrinkWrap;
  const _MediaGrid({required this.items, this.shrinkWrap = false});

  bool _isPdfData(String base64Str, [String? name]) {
    if (name != null && name.toLowerCase().endsWith('.pdf')) return true;
    try {
      final bytes = base64Decode(base64Str);
      return bytes.length > 4 &&
          bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isPdf = _isPdfData(item.base64, item.name);

        return InkWell(
          onTap: () {
            if (isPdf) {
              openBase64InNewTab(item.base64, 'pdf');
            } else {
              showDialog(
                context: context,
                builder: (context) => _SingleMediaDialog(item: item),
              );
            }
          },
          borderRadius: BorderRadius.circular(Tok.rMd),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Tok.bg,
              borderRadius: BorderRadius.circular(Tok.rMd),
              border: Border.all(color: Tok.border),
            ),
            child: isPdf
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 48,
                        color: Tok.danger,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: Tok.textHi,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Click to view PDF',
                        style: TextStyle(
                          fontSize: 11,
                          color: Tok.brand,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(Tok.rMd),
                    child: Image.memory(
                      base64Decode(item.base64),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.picture_as_pdf_rounded,
                            size: 48,
                            color: Tok.danger,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.name,
                            style: TextStyle(fontSize: 12, color: Tok.textHi),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _SingleMediaDialog extends StatelessWidget {
  final _MediaItem item;

  const _SingleMediaDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
                  Text(item.name, style: Tok.h2),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => Navigator.pop(context),
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
                  child: Image.memory(
                    base64Decode(item.base64),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificateEditorModal extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> requestData;
  final Uint8List fileBytes;
  final String fileName;
  final String fileExtension;
  final VoidCallback onUploaded;

  const _CertificateEditorModal({
    required this.docId,
    required this.requestData,
    required this.fileBytes,
    required this.fileName,
    required this.fileExtension,
    required this.onUploaded,
  });

  @override
  State<_CertificateEditorModal> createState() =>
      _CertificateEditorModalState();
}

class _SignatureStamp {
  final Uint8List rawBytes;
  final Uint8List bytes;
  Offset position;
  double width;

  _SignatureStamp({
    required this.rawBytes,
    required this.bytes,
    required this.position,
    this.width = 130,
  });

  double get height => width / 2;
}

class _CertificateEditorModalState extends State<_CertificateEditorModal> {
  static const double _canvasWidth = 600;
  static const double _canvasHeight = 800;
  static const EdgeInsets _pdfPreviewPageMargin = EdgeInsets.fromLTRB(
    20,
    8,
    20,
    12,
  );
  static const int _maxSignatures = 3;
  static const List<(String, Color)> _coverColors = [
    ('White', Color(0xFFFFFFFF)),
    ('Light gray', Color(0xFFE0E0E0)),
    ('Gray', Color(0xFFBDBDBD)),
    ('Dark gray', Color(0xFF757575)),
    ('Black', Color(0xFF000000)),
    ('Light yellow', Color(0xFFFFF9C4)),
  ];

  late final TextEditingController _certNoController;
  final _textController = TextEditingController();
  final _horizontalCanvasController = ScrollController();
  final List<_SignatureStamp> _signatures = [];
  bool _cleanSignatureBg = true;
  bool _coverTextBackground = false;
  Color _coverTextColor = const Color(0xFFFFFFFF);
  Uint8List? _finalPdfBytes;
  Object? _generationError;
  bool _isProcessingPdf = false;
  bool _isUploading = false;
  int _renderVersion = 0;
  Size _pageSize = const Size(595, 842);
  Offset _textPosition = const Offset(70, 500);
  double _textFontSize = 18;
  double _textBoxWidth = 300;
  double _coverTextPadding = 6;
  double _canvasZoom = 1;

  double get _pagePreviewWidth =>
      _canvasWidth - _pdfPreviewPageMargin.horizontal;

  double get _pagePreviewHeight =>
      _pagePreviewWidth * _pageSize.height / _pageSize.width;

  Offset _pagePositionToPdf(Offset position, double scale) => Offset(
    (position.dx - _pdfPreviewPageMargin.left) * scale,
    (position.dy - _pdfPreviewPageMargin.top) * scale,
  );

  @override
  void initState() {
    super.initState();
    final shortId = widget.docId.length >= 6
        ? widget.docId.substring(0, 6).toUpperCase()
        : widget.docId.toUpperCase();
    _certNoController = TextEditingController(
      text: widget.requestData['certificate_no'] ?? 'FSIC-2025-$shortId',
    );
    _generateStampedPdf();
  }

  @override
  void dispose() {
    _certNoController.dispose();
    _textController.dispose();
    _horizontalCanvasController.dispose();
    super.dispose();
  }

  Uint8List _removeWhiteBg(Uint8List rawBytes) {
    final decoded = img_lib.decodeImage(rawBytes);
    if (decoded == null) {
      throw const FormatException('The selected signature image is invalid.');
    }
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final pixel = decoded.getPixel(x, y);
        if (pixel.r > 200 && pixel.g > 200 && pixel.b > 200) {
          decoded.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }
    return Uint8List.fromList(img_lib.encodePng(decoded));
  }

  Size _measureTextContent(String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: _textFontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _textBoxWidth);
    final lineWidths = painter.computeLineMetrics().map((line) => line.width);
    final width = lineWidths.fold<double>(
      0,
      (widest, lineWidth) => lineWidth > widest ? lineWidth : widest,
    );
    return Size(width, painter.height);
  }

  Future<void> _pickSignatures() async {
    final remaining = _maxSignatures - _signatures.length;
    if (remaining <= 0) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      allowMultiple: remaining > 1,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;

    final stamps = <_SignatureStamp>[];
    try {
      for (final file in result.files.take(remaining)) {
        final bytes = file.bytes;
        if (bytes == null) {
          throw StateError('Could not read signature image "${file.name}".');
        }
        final signatureBytes = _cleanSignatureBg
            ? _removeWhiteBg(bytes)
            : bytes;
        final index = _signatures.length + stamps.length;
        stamps.add(
          _SignatureStamp(
            rawBytes: bytes,
            bytes: signatureBytes,
            position: Offset(350, 600 - index * 70),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not import signature image: $error'),
            backgroundColor: Tok.danger,
          ),
        );
      }
      return;
    }
    _signatures.addAll(stamps);
    setState(() {});
    await _generateStampedPdf();
  }

  Future<void> _generateStampedPdf() async {
    final version = ++_renderVersion;
    setState(() {
      _isProcessingPdf = true;
      _generationError = null;
    });

    syncfusion.PdfDocument? document;
    try {
      final extension = widget.fileExtension.toLowerCase();
      final isImage = ['jpg', 'jpeg', 'png'].contains(extension);
      if (isImage) {
        document = syncfusion.PdfDocument();
        final page = document.pages.add();
        page.graphics.drawImage(
          syncfusion.PdfBitmap(widget.fileBytes),
          Rect.fromLTWH(0, 0, page.size.width, page.size.height),
        );
      } else {
        document = syncfusion.PdfDocument(inputBytes: widget.fileBytes);
      }

      if (document.pages.count == 0) {
        throw const FormatException('The selected document has no pages.');
      }

      final page = document.pages[0];
      final scale = page.size.width / _pagePreviewWidth;
      final padding = _coverTextBackground ? _coverTextPadding * scale : 0.0;

      final text = _textController.text.trim();
      if (text.isNotEmpty) {
        final textFont = syncfusion.PdfStandardFont(
          syncfusion.PdfFontFamily.helvetica,
          _textFontSize * scale,
        );
        final textSize = textFont.measureString(
          text,
          layoutArea: Size(_textBoxWidth * scale, page.size.height),
        );
        final textPosition = _pagePositionToPdf(_textPosition, scale);
        final textBounds = Rect.fromLTWH(
          textPosition.dx + padding,
          textPosition.dy + padding,
          _textBoxWidth * scale,
          textSize.height,
        );
        if (_coverTextBackground) {
          page.graphics.drawRectangle(
            brush: syncfusion.PdfSolidBrush(
              syncfusion.PdfColor(
                (_coverTextColor.r * 255).round().clamp(0, 255),
                (_coverTextColor.g * 255).round().clamp(0, 255),
                (_coverTextColor.b * 255).round().clamp(0, 255),
              ),
            ),
            bounds: Rect.fromLTWH(
              textPosition.dx,
              textPosition.dy,
              textSize.width + padding * 2,
              textBounds.height + padding * 2,
            ),
          );
        }
        page.graphics.drawString(
          text,
          textFont,
          bounds: textBounds,
          brush: syncfusion.PdfBrushes.black,
          format: syncfusion.PdfStringFormat(
            lineAlignment: syncfusion.PdfVerticalAlignment.top,
          ),
        );
      }

      for (final signature in _signatures) {
        final signaturePosition = _pagePositionToPdf(signature.position, scale);
        page.graphics.drawImage(
          syncfusion.PdfBitmap(signature.bytes),
          Rect.fromLTWH(
            signaturePosition.dx,
            signaturePosition.dy,
            signature.width * scale,
            signature.height * scale,
          ),
        );
      }

      final bytes = Uint8List.fromList(await document.save());
      if (mounted && version == _renderVersion) {
        setState(() {
          _pageSize = Size(page.size.width, page.size.height);
          _finalPdfBytes = bytes;
        });
      }
    } catch (error) {
      debugPrint('Certificate PDF editing failed: $error');
      if (mounted && version == _renderVersion) {
        setState(() => _generationError = error);
      }
    } finally {
      document?.dispose();
      if (mounted && version == _renderVersion) {
        setState(() => _isProcessingPdf = false);
      }
    }
  }

  Future<void> _saveDraft() async {
    final bytes = _finalPdfBytes;
    if (bytes == null || _isProcessingPdf || _generationError != null) return;
    setState(() => _isUploading = true);

    try {
      await FirebaseFirestore.instance
          .collection('inspection_requests')
          .doc(widget.docId)
          .update({
            'certificate_base64': base64Encode(bytes),
            'certificate_extension': 'pdf',
            'certificate_filename': 'FSIC_${widget.docId}.pdf',
            'certificate_no': _certNoController.text.trim(),
            'certificate_status': 'pending_review',
            'issued_at': FieldValue.delete(),
            'expiration_date': FieldValue.delete(),
            'updated_at': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.pop(context);
        widget.onUploaded();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF saved and sent to the Fire Marshal for review.'),
            backgroundColor: Tok.ok,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save the certificate: $error'),
            backgroundColor: Tok.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _signatureControl(int index) {
    final signature = _signatures[index];
    return Chip(
      avatar: Image.memory(signature.bytes, width: 28, height: 22),
      label: Text('Signature ${index + 1}'),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: () {
        setState(() => _signatures.removeAt(index));
        _generateStampedPdf();
      },
    );
  }

  Widget _resizeHandle({
    required ValueChanged<Offset> onResize,
    required VoidCallback onResizeEnd,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) => onResize(details.delta),
      onPanEnd: (_) => onResizeEnd(),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Tok.brand,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: const Icon(
          Icons.open_in_full_rounded,
          size: 13,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final textContentSize = _measureTextContent(_textController.text.trim());
    final canSave =
        !_isUploading &&
        !_isProcessingPdf &&
        _generationError == null &&
        _finalPdfBytes != null;
    final isImage = [
      'jpg',
      'jpeg',
      'png',
    ].contains(widget.fileExtension.toLowerCase());

    return Dialog(
      backgroundColor: Tok.surface,
      insetPadding: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Tok.surfaceAlt,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Certificate PDF',
                              style: Tok.h2.copyWith(fontSize: 16),
                            ),
                            Text(
                              '${widget.fileName} · Text and signatures are placed on page 1; up to 3 signatures.',
                              style: Tok.bodySm.copyWith(
                                color: Tok.textLo,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: TextField(
                          controller: _certNoController,
                          style: Tok.bodySm.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Certificate no.',
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 190,
                        child: TextField(
                          controller: _textController,
                          onChanged: (_) => _generateStampedPdf(),
                          style: Tok.bodySm,
                          decoration: const InputDecoration(
                            labelText: 'Text to place on PDF',
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _signatures.length == _maxSignatures
                            ? null
                            : _pickSignatures,
                        icon: const Icon(Icons.draw_rounded, size: 16),
                        label: Text(
                          'Add signature (${_signatures.length}/$_maxSignatures)',
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _finalPdfBytes == null || _isProcessingPdf
                            ? null
                            : () => openBase64InNewTab(
                                base64Encode(_finalPdfBytes!),
                                'pdf',
                              ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Preview'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: canSave ? _saveDraft : null,
                        icon: _isUploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 16),
                        label: const Text('Save for Review'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Tok.ok,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: Tok.textHi,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Checkbox(
                        value: _cleanSignatureBg,
                        onChanged: _signatures.isEmpty
                            ? null
                            : (value) {
                                final shouldClean = value ?? true;
                                setState(() {
                                  _cleanSignatureBg = shouldClean;
                                  for (var i = 0; i < _signatures.length; i++) {
                                    final rawBytes = _signatures[i].rawBytes;
                                    _signatures[i] = _SignatureStamp(
                                      rawBytes: rawBytes,
                                      bytes: shouldClean
                                          ? _removeWhiteBg(rawBytes)
                                          : rawBytes,
                                      position: _signatures[i].position,
                                      width: _signatures[i].width,
                                    );
                                  }
                                });
                                _generateStampedPdf();
                              },
                      ),
                      Text(
                        'Remove white signature backgrounds',
                        style: Tok.bodySm,
                      ),
                      const SizedBox(width: 12),
                      Checkbox(
                        value: _coverTextBackground,
                        onChanged: (value) {
                          setState(() => _coverTextBackground = value ?? false);
                          _generateStampedPdf();
                        },
                      ),
                      Text('Cover text beneath text box', style: Tok.bodySm),
                      if (_coverTextBackground) ...[
                        const SizedBox(width: 8),
                        DropdownButton<Color>(
                          value: _coverTextColor,
                          isDense: true,
                          underline: const SizedBox.shrink(),
                          onChanged: (color) {
                            if (color == null) return;
                            setState(() => _coverTextColor = color);
                            _generateStampedPdf();
                          },
                          items: [
                            for (final (label, color) in _coverColors)
                              DropdownMenuItem(
                                value: color,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: color,
                                        border: Border.all(color: Tok.border),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(label, style: Tok.bodySm),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Padding ${_coverTextPadding.round()}',
                          style: Tok.bodySm,
                        ),
                        SizedBox(
                          width: 130,
                          child: Slider(
                            value: _coverTextPadding,
                            min: 0,
                            max: 40,
                            divisions: 20,
                            label: '${_coverTextPadding.round()} px',
                            onChanged: (value) {
                              setState(() => _coverTextPadding = value);
                            },
                            onChangeEnd: (_) => _generateStampedPdf(),
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),
                      ...List.generate(_signatures.length, _signatureControl),
                      const SizedBox(width: 12),
                      const Icon(Icons.zoom_out, size: 16),
                      SizedBox(
                        width: 130,
                        child: Slider(
                          value: _canvasZoom,
                          min: 1,
                          max: 2.5,
                          divisions: 6,
                          label: '${(_canvasZoom * 100).round()}%',
                          onChanged: (value) {
                            setState(() => _canvasZoom = value);
                          },
                        ),
                      ),
                      Text(
                        '${(_canvasZoom * 100).round()}%',
                        style: Tok.bodySm,
                      ),
                      const Spacer(),
                      if (_generationError != null)
                        Expanded(
                          child: Text(
                            'PDF edit failed: $_generationError',
                            style: Tok.bodySm.copyWith(color: Tok.danger),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else if (_isProcessingPdf)
                        Text(
                          'Updating PDF…',
                          style: Tok.bodySm.copyWith(color: Tok.textLo),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Tok.border),
            Expanded(
              child: Container(
                color: Tok.bg,
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final pageWidth = _canvasWidth * _canvasZoom;
                    final pageHeight = _canvasHeight * _canvasZoom;
                    final viewportHeight = (constraints.maxHeight - 48).clamp(
                      0.0,
                      double.infinity,
                    );
                    final contentWidth = constraints.maxWidth > pageWidth
                        ? constraints.maxWidth
                        : pageWidth;
                    final contentHeight = viewportHeight > pageHeight
                        ? viewportHeight
                        : pageHeight;

                    return Scrollbar(
                      controller: _horizontalCanvasController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      interactive: true,
                      thickness: 8,
                      child: SingleChildScrollView(
                        controller: _horizontalCanvasController,
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: SizedBox(
                            width: contentWidth,
                            height: contentHeight,
                            child: Center(
                              child: SizedBox(
                                width: pageWidth,
                                height: pageHeight,
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: Transform.scale(
                                    scale: _canvasZoom,
                                    alignment: Alignment.topLeft,
                                    child: Container(
                                      width: _canvasWidth,
                                      height: _canvasHeight,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          Tok.rSm,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black38,
                                            blurRadius: 16,
                                            offset: Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        clipBehavior: Clip.hardEdge,
                                        children: [
                                          Positioned.fill(
                                            child: isImage
                                                ? Positioned(
                                                    left: _pdfPreviewPageMargin
                                                        .left,
                                                    top: _pdfPreviewPageMargin
                                                        .top,
                                                    width: _pagePreviewWidth,
                                                    height: _pagePreviewHeight,
                                                    child: Image.memory(
                                                      widget.fileBytes,
                                                      fit: BoxFit.fill,
                                                    ),
                                                  )
                                                : PdfPreview(
                                                    build: (format) async =>
                                                        widget.fileBytes,
                                                    useActions: false,
                                                    maxPageWidth: _canvasWidth,
                                                    previewPageMargin:
                                                        _pdfPreviewPageMargin,
                                                    padding: EdgeInsets.zero,
                                                    scrollViewDecoration:
                                                        const BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                  ),
                                          ),
                                          if (_textController.text
                                              .trim()
                                              .isNotEmpty)
                                            Positioned(
                                              left: _textPosition.dx,
                                              top: _textPosition.dy,
                                              child: GestureDetector(
                                                onPanUpdate: (details) {
                                                  setState(() {
                                                    _textPosition = Offset(
                                                      (_textPosition.dx +
                                                              details.delta.dx /
                                                                  _canvasZoom)
                                                          .clamp(
                                                            _pdfPreviewPageMargin
                                                                .left,
                                                            math.max(
                                                              _pdfPreviewPageMargin
                                                                  .left,
                                                              _pdfPreviewPageMargin
                                                                      .left +
                                                                  _pagePreviewWidth -
                                                                  _textBoxWidth -
                                                                  2 *
                                                                      _coverTextPadding,
                                                            ),
                                                          ),
                                                      (_textPosition.dy +
                                                              details.delta.dy /
                                                                  _canvasZoom)
                                                          .clamp(
                                                            _pdfPreviewPageMargin
                                                                .top,
                                                            math.max(
                                                              _pdfPreviewPageMargin
                                                                  .top,
                                                              math.min(
                                                                    _canvasHeight,
                                                                    _pdfPreviewPageMargin
                                                                            .top +
                                                                        _pagePreviewHeight,
                                                                  ) -
                                                                  _textFontSize *
                                                                      2.5 -
                                                                  2 *
                                                                      _coverTextPadding,
                                                            ),
                                                          ),
                                                    );
                                                  });
                                                },
                                                onPanEnd: (_) =>
                                                    _generateStampedPdf(),
                                                child: Stack(
                                                  children: [
                                                    Container(
                                                      width:
                                                          _textBoxWidth +
                                                          (_coverTextBackground
                                                              ? 2 *
                                                                    _coverTextPadding
                                                              : 0),
                                                      padding: EdgeInsets.all(
                                                        _coverTextBackground
                                                            ? _coverTextPadding
                                                            : 0,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color: Tok.brand,
                                                        ),
                                                      ),
                                                      child: Stack(
                                                        children: [
                                                          if (_coverTextBackground)
                                                            Positioned(
                                                              left: 0,
                                                              top: 0,
                                                              child: Container(
                                                                width:
                                                                    textContentSize
                                                                        .width +
                                                                    2 *
                                                                        _coverTextPadding,
                                                                height:
                                                                    textContentSize
                                                                        .height +
                                                                    2 *
                                                                        _coverTextPadding,
                                                                color:
                                                                    _coverTextColor,
                                                              ),
                                                            ),
                                                          Text(
                                                            _textController
                                                                .text,
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.black,
                                                              fontSize:
                                                                  _textFontSize,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Positioned(
                                                      right: 0,
                                                      bottom: 0,
                                                      child: _resizeHandle(
                                                        onResize: (delta) {
                                                          setState(() {
                                                            final scaledDelta =
                                                                delta /
                                                                _canvasZoom;
                                                            final textLeft =
                                                                _pdfPreviewPageMargin
                                                                    .left;
                                                            final textTop =
                                                                _pdfPreviewPageMargin
                                                                    .top;
                                                            final pageBottom =
                                                                math.min(
                                                                  _canvasHeight,
                                                                  textTop +
                                                                      _pagePreviewHeight,
                                                                );
                                                            _textBoxWidth =
                                                                (_textBoxWidth +
                                                                        scaledDelta
                                                                            .dx)
                                                                    .clamp(
                                                                      80.0,
                                                                      _pagePreviewWidth,
                                                                    );
                                                            _textFontSize =
                                                                (_textFontSize +
                                                                        scaledDelta.dy *
                                                                            0.15)
                                                                    .clamp(
                                                                      8.0,
                                                                      72.0,
                                                                    );
                                                            _textPosition = Offset(
                                                              _textPosition.dx.clamp(
                                                                textLeft,
                                                                math.max(
                                                                  textLeft,
                                                                  textLeft +
                                                                      _pagePreviewWidth -
                                                                      _textBoxWidth -
                                                                      2 *
                                                                          _coverTextPadding,
                                                                ),
                                                              ),
                                                              _textPosition.dy.clamp(
                                                                textTop,
                                                                math.max(
                                                                  textTop,
                                                                  pageBottom -
                                                                      _textFontSize *
                                                                          2.5 -
                                                                      2 *
                                                                          _coverTextPadding,
                                                                ),
                                                              ),
                                                            );
                                                          });
                                                        },
                                                        onResizeEnd:
                                                            _generateStampedPdf,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          for (final signature in _signatures)
                                            Positioned(
                                              left: signature.position.dx,
                                              top: signature.position.dy,
                                              child: GestureDetector(
                                                onPanUpdate: (details) {
                                                  setState(() {
                                                    signature.position = Offset(
                                                      (signature.position.dx +
                                                              details.delta.dx /
                                                                  _canvasZoom)
                                                          .clamp(
                                                            _pdfPreviewPageMargin
                                                                .left,
                                                            _pdfPreviewPageMargin
                                                                    .left +
                                                                _pagePreviewWidth -
                                                                signature.width,
                                                          ),
                                                      (signature.position.dy +
                                                              details.delta.dy /
                                                                  _canvasZoom)
                                                          .clamp(
                                                            _pdfPreviewPageMargin
                                                                .top,
                                                            math.min(
                                                                  _canvasHeight,
                                                                  _pdfPreviewPageMargin
                                                                          .top +
                                                                      _pagePreviewHeight,
                                                                ) -
                                                                signature
                                                                    .height,
                                                          ),
                                                    );
                                                  });
                                                },
                                                onPanEnd: (_) =>
                                                    _generateStampedPdf(),
                                                child: Stack(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color: Tok.brand,
                                                          width: 1.5,
                                                        ),
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.25,
                                                            ),
                                                      ),
                                                      child: Image.memory(
                                                        signature.bytes,
                                                        width: signature.width,
                                                        height:
                                                            signature.height,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ),
                                                    Positioned(
                                                      right: 0,
                                                      bottom: 0,
                                                      child: _resizeHandle(
                                                        onResize: (delta) {
                                                          setState(() {
                                                            final scaledDelta =
                                                                delta /
                                                                _canvasZoom;
                                                            final change =
                                                                (scaledDelta
                                                                        .dx +
                                                                    scaledDelta
                                                                        .dy) /
                                                                2;
                                                            signature.width =
                                                                (signature.width +
                                                                        change)
                                                                    .clamp(
                                                                      50.0,
                                                                      _canvasWidth -
                                                                          signature
                                                                              .position
                                                                              .dx,
                                                                    );
                                                            signature
                                                                .position = Offset(
                                                              signature
                                                                  .position
                                                                  .dx
                                                                  .clamp(
                                                                    0.0,
                                                                    _canvasWidth -
                                                                        signature
                                                                            .width,
                                                                  ),
                                                              signature
                                                                  .position
                                                                  .dy
                                                                  .clamp(
                                                                    0.0,
                                                                    _canvasHeight -
                                                                        signature
                                                                            .height,
                                                                  ),
                                                            );
                                                          });
                                                        },
                                                        onResizeEnd:
                                                            _generateStampedPdf,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
