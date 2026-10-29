import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../services/inspector_service.dart';
import '../../services/roboflow_service.dart';
import '../../services/theme_provider.dart';
import 'inspector_theme.dart';

void showAuditSheet(
    BuildContext context,
    String docId,
    Map<String, dynamic> data, {
      bool readOnly = false,
    }) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Tok.surface,
    isScrollControlled: true,
    useSafeArea: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Tok.rMd)),
    ),
    builder: (sheetContext) => _AuditSheet(
      docId: docId,
      data: data,
      readOnly: readOnly,
    ),
  );
}

class _AuditSheet extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool readOnly;
  const _AuditSheet({
    required this.docId,
    required this.data,
    this.readOnly = false,
  });

  @override
  State<_AuditSheet> createState() => _AuditSheetState();
}

class _AuditSheetState extends State<_AuditSheet> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _evidenceImages = [];
  final Map<String, List<RoboflowPrediction>> _evidenceDetections = {};
  final Set<String> _analyzingImages = {};
  bool _isUploading = false;
  String? _readinessHint;

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final TextEditingController _inspectorRemarksController = TextEditingController();

  @override
  void dispose() {
    _signatureController.dispose();
    _inspectorRemarksController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_evidenceImages.length >= 5) {
      _showSnack('Maximum 5 photos allowed', Tok.warn);
      return;
    }

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Tok.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Tok.rMd)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add Evidence Photo', style: Tok.h3),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(
                  Icons.camera_alt_outlined,
                  color: Tok.brandSoft,
                ),
                title: Text(
                  'Take Photo with Camera',
                  style: TextStyle(color: Tok.textHi, fontSize: 14),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
                contentPadding: EdgeInsets.zero,
              ),
              Divider(height: 1, color: Tok.borderSoft),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: Tok.ok),
                title: Text(
                  'Upload Image from Gallery',
                  style: TextStyle(color: Tok.textHi, fontSize: 14),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    if (source == ImageSource.gallery) {
      final List<XFile> selected = await _picker.pickMultiImage(
        imageQuality: 25,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (selected.isNotEmpty) {
        final remainingSlots = 5 - _evidenceImages.length;
        final imagesToAdd = selected.take(remainingSlots).toList();

        setState(() {
          _evidenceImages.addAll(imagesToAdd);
        });

        for (final img in imagesToAdd) {
          _analyzeImage(img);
        }

        if (selected.length > remainingSlots) {
          _showSnack('Only $remainingSlots image(s) added. Maximum 5 photos allowed.', Tok.warn);
        }
      }
    } else {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 25,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image != null) {
        setState(() => _evidenceImages.add(image));
        _analyzeImage(image);
      }
    }
  }

  Future<void> _analyzeImage(XFile image) async {
    final roboflow = Provider.of<RoboflowService>(context, listen: false);
    setState(() => _analyzingImages.add(image.path));
    try {
      final bytes = await image.readAsBytes();
      final response = await roboflow.detectFromBytes(bytes);
      if (response != null && mounted) {
        setState(() {
          _evidenceDetections[image.path] = response.predictions;
        });
      }
    } catch (e) {
      debugPrint('Roboflow AI analysis error: $e');
    } finally {
      if (mounted) {
        setState(() => _analyzingImages.remove(image.path));
      }
    }
  }

  Future<void> _analyzeAllImages() async {
    for (final image in _evidenceImages) {
      await _analyzeImage(image);
    }
  }

  Future<void> _markAsComplete() async {
    if (_evidenceImages.isEmpty) {
      _showHint('Add at least one evidence photo.');
      return;
    }
    if (_signatureController.isEmpty) {
      _showHint('Collect the client signature before finalizing.');
      return;
    }

    setState(() {
      _isUploading = true;
      _readinessHint = null;
    });

    final inspectorService = Provider.of<InspectorService>(context, listen: false);

    try {
      final Uint8List? sigBytes = await _signatureController.toPngBytes();

      final isOnline = await inspectorService.finalizeAudit(
        docId: widget.docId,
        signatureBytes: sigBytes,
        evidenceImages: _evidenceImages,
        evidenceDetections: _evidenceDetections,
        inspectorRemarks: _inspectorRemarksController.text.trim(),
      );

      if (!mounted) return;
      if (isOnline) {
        _showSnack('Audit finalized.', Tok.ok);
      } else {
        _showSnack('Saved locally. Will sync when online.', Tok.info);
      }

      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _evidenceImages.clear();
        _evidenceDetections.clear();
        _signatureController.clear();
      });
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _showSnack('Error: $e', Tok.danger);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showHint(String msg) {
    setState(() => _readinessHint = msg);
    _showSnack(msg, Tok.warn);
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<ThemeProvider>(context);
    final data = widget.data;
    final isAssigned = (data['status'] ?? '') == 'assigned';
    final canFinalize = !widget.readOnly && isAssigned;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Tok.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (data['property_name'] ?? 'Audit details').toString(),
                        style: Tok.h2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ref · ${widget.docId.substring(0, widget.docId.length < 8 ? widget.docId.length : 8).toUpperCase()}',
                        style: Tok.caption.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
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
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Details', style: Tok.h3),
                  const SizedBox(height: 8),
                  _DefinitionList(entries: [
                    _Def(label: 'Property', value: data['property_name']),
                    _Def(label: 'Address', value: data['address']),
                    _Def(label: 'Audit type', value: data['inspection_type']),
                    _Def(label: 'Contact number', value: data['phone']),
                    _Def(label: 'Client email', value: data['email']),
                    _Def(label: 'Client Remarks', value: data['remarks'] ?? 'No special remarks'),
                    if (data['inspector_remarks'] != null)
                      _Def(label: 'Inspector Remarks', value: data['inspector_remarks']),
                  ]),

                  if (data['lat'] != null && data['lng'] != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Pinned Location', style: Tok.h3),
                        InkWell(
                          onTap: () {
                            final lat = (data['lat'] as num).toDouble();
                            final lng = (data['lng'] as num).toDouble();
                            final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                            launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
                          child: Row(
                            children: [
                              Icon(Icons.directions_rounded, size: 14, color: Tok.brandSoft),
                              const SizedBox(width: 4),
                              Text(
                                'Directions',
                                style: Tok.caption.copyWith(
                                  color: Tok.brandSoft,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Tok.rMd),
                        border: Border.all(color: Tok.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(
                            (data['lat'] as num).toDouble(),
                            (data['lng'] as num).toDouble(),
                          ),
                          initialZoom: 15.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.pyrafullapp.app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                  (data['lat'] as num).toDouble(),
                                  (data['lng'] as num).toDouble(),
                                ),
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.red,
                                  size: 38,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (canFinalize) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: Text('Evidence', style: Tok.h3)),
                        Text(
                          '${_evidenceImages.length} / 5',
                          style: Tok.caption.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _EvidenceStrip(
                      images: _evidenceImages,
                      analyzingImages: _analyzingImages,
                      detections: _evidenceDetections,
                      onAdd: _pickImage,
                      onRemove: (f) => setState(() {
                        _evidenceImages.remove(f);
                        _evidenceDetections.remove(f.path);
                      }),
                    ),
                    _AiDetectionResultsCard(
                      images: _evidenceImages,
                      analyzingImages: _analyzingImages,
                      detections: _evidenceDetections,
                      onReAnalyze: _analyzeAllImages,
                    ),

                    const SizedBox(height: 16),
                    Text('Inspector Remarks / Findings', style: Tok.h3),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _inspectorRemarksController,
                      maxLines: 3,
                      style: Tok.body,
                      decoration: InputDecoration(
                        hintText: 'Add remarks on captured evidence (e.g. equipment present but unverified by AI, hazard observations, or notes)...',
                        hintStyle: Tok.bodySm.copyWith(color: Tok.textLo),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Tok.rMd),
                          borderSide: BorderSide(color: Tok.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Tok.rMd),
                          borderSide: BorderSide(color: Tok.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Tok.rMd),
                          borderSide: BorderSide(color: Tok.brandSoft),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Text('Client signature', style: Tok.h3),
                    const SizedBox(height: 8),
                    _SignatureBlock(controller: _signatureController),
                  ],
                ],
              ),
            ),
          ),

          if (canFinalize) ...[
            Divider(height: 1, color: Tok.borderSoft),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_readinessHint != null) ...[
                      Text(
                        _readinessHint!,
                        style: Tok.bodySm.copyWith(color: Tok.warn),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _markAsComplete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Tok.ok,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Tok.ok.withValues(alpha: 0.4),
                          disabledForegroundColor: Colors.white70,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Tok.rMd),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _isUploading
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text('Finalize audit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Def {
  final String label;
  final dynamic value;
  const _Def({required this.label, required this.value});
}

class _DefinitionList extends StatelessWidget {
  final List<_Def> entries;
  const _DefinitionList({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tok.bg,
        borderRadius: BorderRadius.circular(Tok.rMd),
        border: Border.all(color: Tok.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entries[i].label.toUpperCase(),
                    style: Tok.label,
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    (entries[i].value ?? 'N/A').toString(),
                    style: Tok.body,
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
            ),
            if (i < entries.length - 1)
              Divider(height: 1, color: Tok.borderSoft),
          ],
        ],
      ),
    );
  }
}

class _EvidenceStrip extends StatelessWidget {
  final List<XFile> images;
  final Set<String> analyzingImages;
  final Map<String, List<RoboflowPrediction>> detections;
  final VoidCallback onAdd;
  final ValueChanged<XFile> onRemove;

  const _EvidenceStrip({
    required this.images,
    required this.analyzingImages,
    required this.detections,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...images.map(
                (file) {
              final isAnalyzing = analyzingImages.contains(file.path);
              final detectedList = detections[file.path] ?? [];
              final hasDetections = detectedList.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Tok.rSm),
                      child: Image.file(
                        File(file.path),
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (isAnalyzing)
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(Tok.rSm),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Tok.brandSoft,
                            ),
                          ),
                        ),
                      )
                    else if (hasDetections)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Tok.ok.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.smart_toy_outlined, size: 11, color: Colors.white),
                              const SizedBox(width: 3),
                              Text(
                                '${detectedList.length}',
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
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => onRemove(file),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
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
                ),
              );
            },
          ),
          if (images.length < 5)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Tok.surface,
                  borderRadius: BorderRadius.circular(Tok.rSm),
                  border: Border.all(color: Tok.border),
                ),
                child: Icon(
                  Icons.add_a_photo_outlined,
                  size: 22,
                  color: Tok.brandSoft,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AiDetectionResultsCard extends StatelessWidget {
  final List<XFile> images;
  final Set<String> analyzingImages;
  final Map<String, List<RoboflowPrediction>> detections;
  final VoidCallback onReAnalyze;

  const _AiDetectionResultsCard({
    required this.images,
    required this.analyzingImages,
    required this.detections,
    required this.onReAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    final isAnyAnalyzing = analyzingImages.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Tok.surface,
        borderRadius: BorderRadius.circular(Tok.rMd),
        border: Border.all(color: Tok.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology_outlined,
                size: 18,
                color: Tok.brandSoft,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Roboflow AI Evidence Detections',
                  style: TextStyle(
                    color: Tok.textHi,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isAnyAnalyzing)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Tok.brandSoft,
                  ),
                )
              else
                InkWell(
                  onTap: onReAnalyze,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'Re-analyze',
                      style: TextStyle(
                        color: Tok.brandSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: Tok.borderSoft),
          const SizedBox(height: 8),
          for (int i = 0; i < images.length; i++) ...[
            _buildImageDetectionRow(images[i], i + 1),
            if (i < images.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  bool _isHazardClass(String className) {
    final lower = className.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
    return lower.contains('cigarette') ||
        lower.contains('firecracker') ||
        lower.contains('flammable') ||
        lower.contains('lighter') ||
        lower.contains('loaded outlet') ||
        lower.contains('overload') ||
        lower.contains('exposed wiring') ||
        lower.contains('exposed wired') ||
        lower.contains('wiring') ||
        lower.contains('wired') ||
        lower.contains('damaged wire') ||
        lower.contains('spark') ||
        lower.contains('bidon') ||
        lower.contains('hazard') ||
        lower.contains('combustible') ||
        lower.contains('danger');
  }

  String _formatClassName(String rawCls) {
    String clean = rawCls
        .replaceAll('sparks - v1 2022-08-01 10:00pm', 'Sparks')
        .replaceAll('--t1', '')
        .replaceAll('--t2', '')
        .replaceAll('--t3', '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');

    return clean
        .split(' ')
        .where((w) => w.trim().isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  List<Map<String, String>> _processPredictions(List<RoboflowPrediction> rawPreds) {
    return rawPreds.map((p) {
      final rawCls = p.className;
      final formattedName = _formatClassName(rawCls);

      final pctRaw = p.confidencePercentage.replaceAll('%', '').replaceAll('(', '').replaceAll(')', '').trim();
      final pctDisplay = pctRaw.isNotEmpty ? '$pctRaw%' : '${(p.confidence * 100).toStringAsFixed(1)}%';

      return {
        'name': formattedName,
        'pct': pctDisplay,
      };
    }).toList();
  }

  Widget _buildImageDetectionRow(XFile file, int index) {
    final isAnalyzing = analyzingImages.contains(file.path);
    final preds = detections[file.path] ?? [];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Tok.rSm),
          child: Image.file(
            File(file.path),
            width: 38,
            height: 38,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Evidence Photo #$index',
                style: Tok.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Tok.textHi,
                ),
              ),
              const SizedBox(height: 2),
              if (isAnalyzing)
                Text(
                  'Analyzing with Roboflow AI...',
                  style: TextStyle(color: Tok.brandSoft, fontSize: 11),
                )
              else if (preds.isEmpty)
                Text(
                  'No objects detected',
                  style: TextStyle(color: Tok.textLo, fontSize: 11),
                )
              else ...[
                Builder(builder: (context) {
                  final processed = _processPredictions(preds);
                  final compliant = processed.where((i) => !_isHazardClass(i['name']!)).toList();
                  final hazard = processed.where((i) => _isHazardClass(i['name']!)).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (compliant.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 11, color: Tok.ok),
                            const SizedBox(width: 4),
                            Text('Compliant', style: TextStyle(color: Tok.ok, fontSize: 10, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: compliant.map((item) {
                            final name = item['name']!;
                            final pct = item['pct']!;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Tok.ok.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Tok.ok.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                '$name $pct',
                                style: TextStyle(color: Tok.textHi, fontSize: 10, fontWeight: FontWeight.w500),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (hazard.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 11, color: Tok.danger),
                            const SizedBox(width: 4),
                            Text('Fire Hazard', style: TextStyle(color: Tok.danger, fontSize: 10, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: hazard.map((item) {
                            final name = item['name']!;
                            final pct = item['pct']!;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Tok.danger.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Tok.danger.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                '$name $pct',
                                style: TextStyle(color: Tok.danger, fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SignatureBlock extends StatelessWidget {
  final SignatureController controller;
  const _SignatureBlock({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tok.bg,
        borderRadius: BorderRadius.circular(Tok.rMd),
        border: Border.all(color: Tok.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Signature(
            controller: controller,
            height: 160,
            backgroundColor: Colors.white,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: Tok.surface,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Sign above with a finger or stylus.',
                    style: Tok.caption,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => controller.clear(),
                  icon: Icon(
                    Icons.clear_rounded,
                    size: 14,
                    color: Tok.danger,
                  ),
                  label: Text(
                    'Clear',
                    style: TextStyle(
                      color: Tok.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}