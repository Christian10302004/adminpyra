import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../admin_theme.dart';

class BarangayManagementView extends StatefulWidget {
  const BarangayManagementView({super.key});

  @override
  State<BarangayManagementView> createState() => _BarangayManagementViewState();
}

class _BarangayManagementViewState extends State<BarangayManagementView> {
  final _nameController = TextEditingController();
  LatLng _selectedLoc = const LatLng(8.5106, 125.9793);
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _registerBarangay() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barangay name is required'),
          backgroundColor: Tok.warn,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('barangays').add({
        'name': name,
        'lat': _selectedLoc.latitude,
        'lng': _selectedLoc.longitude,
        'created_at': FieldValue.serverTimestamp(),
      });
      _nameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Barangay registered'),
            backgroundColor: Tok.ok,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: Tok.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openFullscreenMap() async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (dialogContext) => _FullscreenMapDialog(
        initialLoc: _selectedLoc,
        nameController: _nameController,
        isSaving: _isSaving,
        onRegister: () async {
          await _registerBarangay();
          if (dialogContext.mounted && _nameController.text.isEmpty) {
            Navigator.of(dialogContext).pop();
          }
        },
        onLocationChanged: (latlng) {
          setState(() => _selectedLoc = latlng);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final panelHeight = (media.size.height - 220).clamp(420.0, 900.0);
    final mapHeight = (panelHeight - 320).clamp(200.0, 500.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Register a barangay', style: Tok.h2),
          const SizedBox(height: 2),
          Text(
            'Set the barangay hall location used for heat-map density.',
            style: Tok.bodySm.copyWith(color: Tok.textLo, fontSize: 11),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 1000;

              final form = Panel(
                title: 'Barangay details',
                child: SizedBox(
                  height: panelHeight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _FieldLabel('Barangay name', required: true),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nameController,
                        style: Tok.body,
                        decoration: _inputDecoration('e.g. Poblacion'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: _FieldLabel('Barangay hall location'),
                          ),
                          _IconActionButton(
                            icon: Icons.fullscreen_rounded,
                            tooltip: 'Open fullscreen map',
                            onPressed: _openFullscreenMap,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Fixed-height map with a fullscreen button overlaid.
                      SizedBox(
                        height: mapHeight,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(Tok.rMd),
                                  border: Border.all(color: Tok.border),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: _selectedLoc,
                                    initialZoom: 14,
                                    onTap: (_, latlng) => setState(
                                            () => _selectedLoc = latlng),
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.pyra.check',
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: _selectedLoc,
                                          width: 32,
                                          height: 32,
                                          child: const Icon(
                                            Icons.location_on_rounded,
                                            color: Tok.brand,
                                            size: 32,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: _MapOverlayButton(
                                icon: Icons.fullscreen_rounded,
                                tooltip: 'Open fullscreen map',
                                onPressed: _openFullscreenMap,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the map to move the marker. Coordinates: '
                            '${_selectedLoc.latitude.toStringAsFixed(4)}, '
                            '${_selectedLoc.longitude.toStringAsFixed(4)}',
                        style: Tok.bodySm.copyWith(
                          color: Tok.textLo,
                          fontSize: 11,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _registerBarangay,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Tok.brand,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Tok.rMd),
                            ),
                            textStyle: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Text('Register barangay'),
                        ),
                      ),
                    ],
                  ),
                ),
              );

              final list = Panel(
                title: 'Registered barangays',
                subtitle: 'Sorted alphabetically',
                padded: false,
                child: SizedBox(
                  height: panelHeight,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('barangays')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Tok.textLo),
                        );
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return const EmptyState(
                          icon: Icons.account_balance_outlined,
                          label: 'No barangays registered',
                        );
                      }
                      return ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Tok.borderSoft,
                          indent: 20,
                          endIndent: 20,
                        ),
                        itemBuilder: (context, index) {
                          final data =
                          docs[index].data() as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.account_balance_outlined,
                                  size: 16,
                                  color: Tok.textMid,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['name'] ?? 'Unnamed',
                                        style: Tok.body.copyWith(
                                            fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        '${(data['lat'] as num).toStringAsFixed(4)}, '
                                            '${(data['lng'] as num).toStringAsFixed(4)}',
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
                                ),
                                IconButton(
                                  tooltip: 'Delete barangay',
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Tok.textLo,
                                    size: 18,
                                  ),
                                  onPressed: () => _confirmDeleteBarangay(
                                    context,
                                    docs[index].id,
                                    (data['name'] ?? 'Barangay').toString(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              );

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: form),
                    const SizedBox(width: 16),
                    Expanded(child: list),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  form,
                  const SizedBox(height: 16),
                  list,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteBarangay(BuildContext context, String docId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Tok.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tok.rLg),
          side: BorderSide(color: Tok.border),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Tok.danger, size: 22),
            const SizedBox(width: 8),
            Text('Delete Barangay', style: Tok.h2),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$name"? This action cannot be undone.',
          style: Tok.body,
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              foregroundColor: Tok.textHi,
              side: BorderSide(color: Tok.border),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('barangays')
                  .doc(docId)
                  .delete();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Barangay "$name" deleted successfully.'),
                    backgroundColor: Tok.ok,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Tok.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: Tok.body.copyWith(color: Tok.textLo),
    filled: true,
    fillColor: Tok.bg,
    isDense: true,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(Tok.rMd),
      borderSide: BorderSide(color: Tok.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(Tok.rMd),
      borderSide: BorderSide(color: Tok.info),
    ),
  );
}

// ===========================================================================
// FULLSCREEN MAP DIALOG
// ===========================================================================
class _FullscreenMapDialog extends StatefulWidget {
  final LatLng initialLoc;
  final TextEditingController nameController;
  final bool isSaving;
  final Future<void> Function() onRegister;
  final ValueChanged<LatLng> onLocationChanged;

  const _FullscreenMapDialog({
    required this.initialLoc,
    required this.nameController,
    required this.isSaving,
    required this.onRegister,
    required this.onLocationChanged,
  });

  @override
  State<_FullscreenMapDialog> createState() => _FullscreenMapDialogState();
}

class _FullscreenMapDialogState extends State<_FullscreenMapDialog> {
  late LatLng _loc;

  @override
  void initState() {
    super.initState();
    _loc = widget.initialLoc;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Tok.bg,
      child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _loc,
                initialZoom: 15,
                onTap: (_, latlng) {
                  setState(() => _loc = latlng);
                  widget.onLocationChanged(latlng);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.pyra.check',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _loc,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Tok.brand,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Positioned(
            top: 16,
            left: 16,
            right: 72,
            child: SafeArea(
              bottom: false,
              child: _GlassPanel(
                child: Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: Tok.textMid,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: widget.nameController,
                        style: Tok.body.copyWith(color: Colors.white),
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          hintText: 'Barangay name',
                          hintStyle: Tok.body.copyWith(
                              color: Colors.white.withValues(alpha: 0.55)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: _MapOverlayButton(
                icon: Icons.close_fullscreen_rounded,
                tooltip: 'Exit fullscreen',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: _GlassPanel(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SELECTED LOCATION',
                            style: Tok.label.copyWith(
                              color: Colors.white.withValues(alpha: 0.6),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_loc.latitude.toStringAsFixed(4)}, '
                                '${_loc.longitude.toStringAsFixed(4)}',
                            style: Tok.body.copyWith(
                              color: Colors.white,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: widget.isSaving
                          ? null
                          : () async => widget.onRegister(),
                      icon: widget.isSaving
                          ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.check_rounded, size: 16),
                      label: Text(widget.isSaving
                          ? 'Saving…'
                          : 'Register barangay'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Tok.brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Tok.rMd),
                        ),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// SMALL PRIMITIVES
// ===========================================================================
class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(Tok.rMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _MapOverlayButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _MapOverlayButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(Tok.rMd),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(Tok.rMd),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Tok.rMd),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _IconActionButton({
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
        borderRadius: BorderRadius.circular(Tok.rSm),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(Tok.rSm),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Tok.rSm),
              border: Border.all(color: Tok.border),
            ),
            child: Icon(icon, size: 16, color: Tok.textMid),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Tok.label.copyWith(color: Tok.textMid, letterSpacing: 0.2),
        children: [
          TextSpan(text: text),
          if (required)
            const TextSpan(text: ' *', style: TextStyle(color: Tok.brand)),
        ],
      ),
    );
  }
}