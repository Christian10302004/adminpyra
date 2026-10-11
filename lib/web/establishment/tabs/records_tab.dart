import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../establishment_theme.dart';

class RecordsTab extends StatefulWidget {
  final String filter;
  const RecordsTab({super.key, this.filter = 'All'});

  @override
  State<RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<RecordsTab> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
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
          ]),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('inspection_requests')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return TableShell(
                    child: EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: 'Database error',
                      subtitle: snapshot.error.toString(),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return TableShell(
                    child: SizedBox(
                      height: 120,
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

                // --- NO STRICT FILTER: Show all records ---
                // (Matches the Dashboard behavior)
                // --------------------------------------------

                // 1. Search Filter
                if (_searchController.text.isNotEmpty) {
                  final q = _searchController.text.toLowerCase().trim();
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final prop =
                    (data['property_name'] ?? '').toString().toLowerCase();
                    final owner =
                    (data['full_name'] ?? data['email'] ?? '')
                        .toString()
                        .toLowerCase();
                    final addr =
                    (data['address'] ?? '').toString().toLowerCase();
                    return prop.contains(q) ||
                        owner.contains(q) ||
                        addr.contains(q);
                  }).toList();
                }

                // 2. Sort
                docs = docs.toList()
                  ..sort((a, b) {
                    final aMap = a.data() as Map<String, dynamic>;
                    final bMap = b.data() as Map<String, dynamic>;
                    final at = aMap['requested_at'] as Timestamp?;
                    final bt = bMap['requested_at'] as Timestamp?;
                    if (at == null && bt == null) return 0;
                    if (at == null) return 1;
                    if (bt == null) return -1;
                    return bt.compareTo(at);
                  });

                // 3. Status Filter
                if (widget.filter != 'All') {
                  docs = docs.where((doc) {
                    final status =
                    ((doc.data() as Map<String, dynamic>)['status'] ?? '')
                        .toString();
                    if (widget.filter == 'pending') {
                      return status != 'completed';
                    }
                    return status == widget.filter;
                  }).toList();
                }

                return TableShell(
                  header: Container(
                    color: Tok.surfaceAlt,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(children: [
                      Expanded(
                        flex: 4,
                        child: Text('PROPERTY / OWNER', style: Tok.label),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('INSPECTOR', style: Tok.label),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('TYPE', style: Tok.label),
                      ),
                      SizedBox(
                        width: 140,
                        child: Text('STATUS', style: Tok.label),
                      ),
                      SizedBox(
                        width: 140,
                        child: Text('CERTIFICATE', style: Tok.label),
                      ),
                      SizedBox(
                        width: 220,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${docs.length} records',
                            style: Tok.label.copyWith(
                              color: Tok.textMid,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  child: docs.isEmpty
                      ? const EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No records found',
                    subtitle:
                    'Click "Request Inspection" above to get started.',
                  )
                      : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Tok.borderSoft,
                    ),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return _RecordRow(
                        data: data,
                        onViewAudit: () =>
                            showFullAuditDialog(context, doc.id, data),
                        onViewCertificate: () =>
                            viewCertificate(context, data),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// _RecordRow Widget
// ===========================================================================
class _RecordRow extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onViewAudit, onViewCertificate;

  const _RecordRow({
    required this.data,
    required this.onViewAudit,
    required this.onViewCertificate,
  });

  @override
  State<_RecordRow> createState() => _RecordRowState();
}

class _RecordRowState extends State<_RecordRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final status = (data['status'] ?? 'pending_approval').toString();
    final certStatus = (data['certificate_status'] ?? '').toString();

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hover
            ? Tok.surfaceAlt.withValues(alpha: 0.55)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
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
                  'Owner: ${(data['full_name'] ?? data['email'] ?? '—')}',
                  style: Tok.bodySm.copyWith(
                    color: Tok.textLo,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Loc: ${(data['address'] ?? '—')}',
                  style: Tok.bodySm.copyWith(
                    color: Tok.textLo,
                    fontSize: 9,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              (data['inspector_name'] ?? '—').toString(),
              style: Tok.bodySm.copyWith(color: Tok.textMid),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              (data['inspection_type'] ?? '—').toString(),
              style: Tok.bodySm.copyWith(color: Tok.textMid),
            ),
          ),
          SizedBox(
            width: 140,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusTag(status: status),
            ),
          ),
          SizedBox(
            width: 140,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Builder(
                builder: (context) {
                  final expTs = data['expiration_date'] as Timestamp?;
                  final isExpired = expTs != null &&
                      expTs.toDate().isBefore(DateTime.now());
                  return CertIndicator(
                    hasCert: certStatus == 'issued',
                    inReview: certStatus == 'pending_review',
                    isExpired: isExpired,
                  );
                },
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                RowActionButton(
                  label: 'View audit',
                  icon: Icons.analytics_outlined,
                  onPressed: widget.onViewAudit,
                ),
                if (certStatus == 'issued') ...[
                  const SizedBox(width: 8),
                  GhostIconButton(
                    icon: Icons.download_rounded,
                    tooltip: 'Download certificate',
                    onPressed: widget.onViewCertificate,
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}