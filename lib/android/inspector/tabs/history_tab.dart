import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../services/theme_provider.dart';
import '../../../services/inspector_service.dart';
import '../inspector_theme.dart';
import '../audit_sheet.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    Provider.of<ThemeProvider>(context);
    final inspectorService = Provider.of<InspectorService>(context);
    final user = inspectorService.currentUser;

    if (user == null) {
      return const EmptyBlock(
        icon: Icons.lock_outline,
        title: 'Authentication required',
        body: 'Please sign in to view completed audits.',
      );
    }

    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: inspectorService.streamCompletedInspections(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingBlock();
        }

        final docs = snapshot.data ?? const [];

        if (docs.isEmpty) {
          return const EmptyBlock(
            icon: Icons.history_edu_outlined,
            title: 'No completed audits',
            body: 'Finalized inspections will appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return _HistoryRow(
              data: data,
              onOpen: () => showAuditSheet(
                context,
                doc.id,
                data,
                readOnly: true,
              ),
            );
          },
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onOpen;
  const _HistoryRow({required this.data, required this.onOpen});

  String _fmtDate(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final d = ts.toDate();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final property = (data['property_name'] ?? 'Untitled').toString();
    final address = (data['address'] ?? '').toString();
    return Container(
      decoration: BoxDecoration(
        color: Tok.surface,
        borderRadius: BorderRadius.circular(Tok.rMd),
        border: Border.all(color: Tok.border),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Tok.ok.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Tok.rSm),
                ),
                child: const Icon(
                  Icons.verified_outlined,
                  size: 15,
                  color: Tok.ok,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property,
                      style: Tok.body.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Completed ${_fmtDate(data['inspected_at'])}',
                      style: Tok.caption,
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        address,
                        style: Tok.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Tok.textLo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
