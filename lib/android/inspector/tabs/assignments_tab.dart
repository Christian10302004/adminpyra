import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../services/theme_provider.dart';
import '../../../services/inspector_service.dart';
import '../inspector_theme.dart';
import '../audit_sheet.dart';

class AssignmentsTab extends StatelessWidget {
  const AssignmentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    Provider.of<ThemeProvider>(context);
    final inspectorService = Provider.of<InspectorService>(context);
    final user = inspectorService.currentUser;

    if (user == null) {
      return const EmptyBlock(
        icon: Icons.lock_outline,
        title: 'Authentication required',
        body: 'Please sign in to view assigned inspections.',
      );
    }

    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: inspectorService.streamAssignedInspections(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingBlock();
        }

        final docs = snapshot.data ?? const [];

        if (docs.isEmpty) {
          return const EmptyBlock(
            icon: Icons.assignment_ind_outlined,
            title: 'No pending assignments',
            body: 'New inspection assignments will appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return _AssignmentRow(
              data: data,
              onOpen: () => showAuditSheet(
                context,
                doc.id,
                data,
                readOnly: false,
              ),
            );
          },
        );
      },
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onOpen;

  const _AssignmentRow({
    required this.data,
    required this.onOpen,
  });

  String _fmtDate(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final d = ts.toDate();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final property = (data['property_name'] ?? 'Untitled Property').toString();
    final address = (data['address'] ?? '').toString();
    final type = (data['inspection_type'] ?? 'Inspection').toString();

    return Container(
      decoration: BoxDecoration(
        color: Tok.surface,
        borderRadius: BorderRadius.circular(Tok.rMd),
        border: Border.all(color: Tok.border),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Tok.brandSoft.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(Tok.rSm),
                    ),
                    child: Icon(
                      Icons.assignment_outlined,
                      size: 16,
                      color: Tok.brandSoft,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property,
                          style: Tok.body.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$type • Assigned ${_fmtDate(data['assigned_at'] ?? data['created_at'])}',
                          style: Tok.caption,
                        ),
                      ],
                    ),
                  ),
                  const StatusTag(label: 'Assigned', color: Tok.indigo),
                ],
              ),
              if (address.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Tok.textLo,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address,
                        style: Tok.bodySm.copyWith(color: Tok.textMid),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (data['lat'] != null && data['lng'] != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.pin_drop_rounded,
                      size: 14,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Pinned Location: ${(data['lat'] as num).toStringAsFixed(4)}, ${(data['lng'] as num).toStringAsFixed(4)}',
                      style: Tok.caption.copyWith(
                        color: Tok.brandSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
