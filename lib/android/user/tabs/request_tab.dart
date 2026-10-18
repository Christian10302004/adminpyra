import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../services/user_service.dart';
import '../user_theme.dart';

class RequestTab extends StatefulWidget {
  final VoidCallback onSubmitted;
  const RequestTab({super.key, required this.onSubmitted});

  @override
  State<RequestTab> createState() => _RequestTabState();
}

class _RequestTabState extends State<RequestTab> {
  final _formKey = GlobalKey<FormState>();
  final _propertyNameController = TextEditingController();
  final _streetController = TextEditingController();
  final _phoneController = TextEditingController();
  final _remarksController = TextEditingController();
  String? _selectedBarangay;
  String _inspectionType = 'Annual Fire Inspection';
  LatLng _pinnedLocation = const LatLng(8.5106, 125.9793);
  bool _isSubmitting = false;

  @override
  void dispose() {
    _propertyNameController.dispose();
    _streetController.dispose();
    _phoneController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final String fullAddress =
        "${_streetController.text.trim()}, Barangay $_selectedBarangay, San Francisco, Agusan del Sur";

    try {
      final userService = Provider.of<UserService>(context, listen: false);
      await userService.submitInspectionRequest(
        propertyName: _propertyNameController.text.trim(),
        address: fullAddress,
        barangay: _selectedBarangay,
        phone: _phoneController.text.trim(),
        inspectionType: _inspectionType,
        remarks: _remarksController.text.trim(),
        latitude: _pinnedLocation.latitude,
        longitude: _pinnedLocation.longitude,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request submitted'),
          backgroundColor: Tok.ok,
          behavior: SnackBarBehavior.floating,
        ),
      );

      _propertyNameController.clear();
      _streetController.clear();
      _phoneController.clear();
      _remarksController.clear();
      setState(() {
        _isSubmitting = false;
        _selectedBarangay = null;
      });
      widget.onSubmitted();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Tok.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Schedule Inspection',
                style: Tok.h2.copyWith(color: colors.textHi)),
            const SizedBox(height: 4),
            Text(
              'Provide the details below so we can reach your property.',
              style: Tok.bodySm.copyWith(color: colors.textMid),
            ),
            const SizedBox(height: 24),

            const _FieldLabel('Property Name', required: true),
            const SizedBox(height: 6),
            _MobileField(
              controller: _propertyNameController,
              hint: 'e.g. Acme Heights',
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter the property name.'
                  : null,
            ),
            const SizedBox(height: 16),

            Text('LOCATION DETAILS',
                style: Tok.label.copyWith(color: colors.textLo)),
            const SizedBox(height: 2),
            Text('San Francisco, Agusan del Sur only.',
                style: Tok.caption.copyWith(color: colors.textLo)),
            const SizedBox(height: 12),

            const _FieldLabel('Street / House Number', required: true),
            const SizedBox(height: 6),
            _MobileField(
              controller: _streetController,
              hint: 'e.g. 123 Rizal Street',
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter the street address.'
                  : null,
            ),
            const SizedBox(height: 16),

            const _FieldLabel('Barangay', required: true),
            const SizedBox(height: 6),
            _BarangayField(
              value: _selectedBarangay,
              onChanged: (v) => setState(() => _selectedBarangay = v),
            ),
            const SizedBox(height: 16),

            const _FieldLabel('Contact Number', required: true),
            const SizedBox(height: 6),
            _MobileField(
              controller: _phoneController,
              hint: '09123456789',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter a contact number.';
                }
                final clean = v.trim();
                if (!clean.startsWith('09')) {
                  return 'Phone number must start with 09 (e.g., 09123456789).';
                }
                if (clean.length != 11) {
                  return 'Phone number must be exactly 11 digits.';
                }
                if (!RegExp(r'^09\d{9}$').hasMatch(clean)) {
                  return 'Enter a valid 11-digit PH mobile number.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            const _FieldLabel('Inspection Type', required: true),
            const SizedBox(height: 6),
            _InspectionTypeField(
              value: _inspectionType,
              onChanged: (v) => setState(() => _inspectionType = v),
            ),
            const SizedBox(height: 16),

            const _FieldLabel('Remarks'),
            const SizedBox(height: 6),
            _MobileField(
              controller: _remarksController,
              hint: 'Any specific concerns (optional)',
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            const _FieldLabel('Pin Establishment Location', required: true),
            const SizedBox(height: 4),
            Text(
              'Tap anywhere on the map below to pin your exact location.',
              style: Tok.caption.copyWith(color: colors.textLo),
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Tok.rMd),
                border: Border.all(color: colors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _pinnedLocation,
                  initialZoom: 14.5,
                  onTap: (tapPosition, point) {
                    setState(() => _pinnedLocation = point);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.pyrafullapp.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _pinnedLocation,
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
            const SizedBox(height: 6),
            Text(
              'Pinned Coordinates: ${_pinnedLocation.latitude.toStringAsFixed(5)}, ${_pinnedLocation.longitude.toStringAsFixed(5)}',
              style: Tok.caption.copyWith(color: Tok.brand, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 28),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Tok.brand,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Tok.brand.withValues(alpha: 0.5),
                  disabledForegroundColor: Colors.white70,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Tok.rMd),
                  ),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text('Submit Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Field label
// ===========================================================================
class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return RichText(
      text: TextSpan(
        style: Tok.label.copyWith(color: colors.textMid, letterSpacing: 0.3),
        children: [
          TextSpan(text: text),
          if (required)
            const TextSpan(text: ' *', style: TextStyle(color: Tok.brand)),
        ],
      ),
    );
  }
}

// ===========================================================================
// Text field
// ===========================================================================

class _MobileField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _MobileField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      validator: validator,
      style: Tok.body.copyWith(color: colors.textHi),
      cursorColor: colors.textHi,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: Tok.body.copyWith(color: colors.textLo),
        filled: true,
        fillColor: colors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tok.rMd),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tok.rMd),
          borderSide: const BorderSide(color: Tok.brand, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tok.rMd),
          borderSide: const BorderSide(color: Tok.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tok.rMd),
          borderSide: const BorderSide(color: Tok.danger, width: 1.4),
        ),
        errorStyle: const TextStyle(
            color: Tok.danger, fontSize: 11, height: 1.3),
      ),
    );
  }
}


// ===========================================================================
// Barangay dropdown
// ===========================================================================
class _BarangayField extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _BarangayField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return StreamBuilder<QuerySnapshot>(
      stream: Provider.of<UserService>(context, listen: false).streamBarangays(),
      builder: (context, snapshot) {
        final List<String> list = snapshot.hasData
            ? snapshot.data!.docs
            .map((doc) => (doc.data() as Map)['name'].toString())
            .toList()
            : <String>[];

        return DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          dropdownColor: colors.surface,
          icon: Icon(Icons.expand_more_rounded,
              size: 18, color: colors.textLo),
          hint: Text('Select barangay',
              style: TextStyle(color: colors.textLo, fontSize: 14)),
          style: Tok.body.copyWith(color: colors.textHi),
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.surface,
            isDense: true,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Tok.rMd),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Tok.rMd),
              borderSide: const BorderSide(color: Tok.brand, width: 1.4),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Tok.rMd),
              borderSide: const BorderSide(color: Tok.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Tok.rMd),
              borderSide: const BorderSide(color: Tok.danger, width: 1.4),
            ),
          ),
          items: list
              .map((b) => DropdownMenuItem(
            value: b,
            child: Text(b,
                style: Tok.body.copyWith(color: colors.textHi)),
          ))
              .toList(),
          onChanged: onChanged,
          validator: (val) => val == null ? 'Please select a barangay.' : null,
        );
      },
    );
  }
}

// ===========================================================================
// Inspection type dropdown
// ===========================================================================
class _InspectionTypeField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _InspectionTypeField({required this.value, required this.onChanged});

  static const _types = <String>[
    'Annual Fire Inspection',
    'Business Permit',
    'New Installation',
    'Fire Drill Assessment',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: colors.surface,
      icon: Icon(Icons.expand_more_rounded,
          size: 18, color: colors.textLo),
      style: Tok.body.copyWith(color: colors.textHi),
      decoration: InputDecoration(
        filled: true,
        fillColor: colors.surface,
        isDense: true,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tok.rMd),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tok.rMd),
          borderSide: const BorderSide(color: Tok.brand, width: 1.4),
        ),
      ),
      items: _types
          .map((t) => DropdownMenuItem(
        value: t,
        child: Text(t,
            style: Tok.body.copyWith(color: colors.textHi)),
      ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}