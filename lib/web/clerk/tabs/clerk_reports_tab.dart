import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../clerk_theme.dart';

class ClerkReportsTab extends StatefulWidget {
  const ClerkReportsTab({super.key});

  @override
  State<ClerkReportsTab> createState() => _ClerkReportsTabState();
}

class _ClerkReportsTabState extends State<ClerkReportsTab> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inspection_requests')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Tok.textLo,
            ),
          );
        }

        final docs = snapshot.data!.docs;
        final stats = _generateStats(docs);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderSection(
                onDownload: () => _downloadPDF(stats),
                isGenerating: _isGenerating,
              ),
              const SizedBox(height: 24),
              _OverviewGrid(stats: stats),
              const SizedBox(height: 32),
              const SectionHeader(
                title: 'Detailed Breakdown',
                subtitle: 'Performance distribution across operational areas.',
              ),
              const SizedBox(height: 16),
              _BarangayPerformanceTable(brgyStats: stats.barangayDistribution),
            ],
          ),
        );
      },
    );
  }

  _ReportStats _generateStats(List<QueryDocumentSnapshot> docs) {
    int total = docs.length;
    int pending = 0;
    int awaitingDocs = 0;
    int submitted = 0;
    int assigned = 0;
    int completed = 0;
    int issued = 0;

    Map<String, int> brgyDistribution = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? '';
      final certStatus = data['certificate_status'] ?? '';
      final address = (data['address'] ?? '').toString();

      if (certStatus == 'issued') {
        issued++;
      } else {
        switch (status) {
          case 'pending_approval':
            pending++;
            break;
          case 'approved_waiting_requirements':
            awaitingDocs++;
            break;
          case 'requirements_submitted':
            submitted++;
            break;
          case 'assigned':
            assigned++;
            break;
          case 'completed':
            completed++;
            break;
        }
      }

      final parts = address.split(',');
      final brgy = parts.length > 1 ? parts[1].trim() : 'Unknown';
      brgyDistribution[brgy] = (brgyDistribution[brgy] ?? 0) + 1;
    }

    return _ReportStats(
      total: total,
      pending: pending,
      awaitingDocs: awaitingDocs,
      submitted: submitted,
      assigned: assigned,
      completed: completed,
      issued: issued,
      barangayDistribution: brgyDistribution,
    );
  }

  Future<void> _downloadPDF(_ReportStats stats) async {
    setState(() => _isGenerating = true);
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('BFP PyraCheck - Operations Report',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 18)),
                    pw.Text(DateTime.now().toString().split(' ')[0]),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Operational Overview',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  <String>['Metric', 'Count'],
                  <String>['Total Requests', stats.total.toString()],
                  <String>['Pending Approval', stats.pending.toString()],
                  <String>[
                    'Awaiting Requirements',
                    stats.awaitingDocs.toString()
                  ],
                  <String>['Files Submitted', stats.submitted.toString()],
                  <String>['Currently Assigned', stats.assigned.toString()],
                  <String>[
                    'Inspections Completed',
                    stats.completed.toString()
                  ],
                  <String>['Certificates Issued', stats.issued.toString()],
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Text('Barangay Distribution',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  <String>['Barangay', 'Requests'],
                  ...stats.barangayDistribution.entries
                      .map((e) => [e.key, e.value.toString()])
                      .toList(),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
        'PyraCheck_Operations_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      debugPrint('PDF Error: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }
}

class _HeaderSection extends StatelessWidget {
  final VoidCallback onDownload;
  final bool isGenerating;
  const _HeaderSection({
    required this.onDownload,
    required this.isGenerating,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: SectionHeader(
            title: 'Operational Reports',
            subtitle: 'Real-time data aggregation and performance tracking.',
          ),
        ),
        ElevatedButton.icon(
          onPressed: isGenerating ? null : onDownload,
          icon: isGenerating
              ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white),
          )
              : const Icon(Icons.picture_as_pdf_outlined, size: 16),
          label: Text(isGenerating ? 'Generating...' : 'Download PDF Report'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Tok.brand,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Tok.rMd),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  final _ReportStats stats;
  const _OverviewGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 900 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: cols,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.2,
          children: [
            _StatCard(
              label: 'Total requests',
              value: stats.total.toString(),
              color: Tok.textHi,
            ),
            _StatCard(
              label: 'Issued certs',
              value: stats.issued.toString(),
              color: Tok.ok,
            ),
            _StatCard(
              label: 'Pending review',
              value: stats.pending.toString(),
              color: Tok.warn,
            ),
            _StatCard(
              label: 'In field',
              value: stats.assigned.toString(),
              color: Tok.info,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Tok.surface,
        borderRadius: BorderRadius.circular(Tok.rLg),
        border: Border.all(color: Tok.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(), style: Tok.label),
          const SizedBox(height: 8),
          Text(value, style: Tok.num.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _BarangayPerformanceTable extends StatelessWidget {
  final Map<String, int> brgyStats;
  const _BarangayPerformanceTable({required this.brgyStats});

  @override
  Widget build(BuildContext context) {
    final sortedEntries = brgyStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return TableShell(
      header: Container(
        color: Tok.surfaceAlt,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text('BARANGAY', style: Tok.label),
            ),
            Expanded(
              flex: 2,
              child: Text('TOTAL REQUESTS', style: Tok.label),
            ),
            Expanded(
              flex: 2,
              child: Text('INTENSITY', style: Tok.label),
            ),
          ],
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sortedEntries.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Tok.borderSoft),
        itemBuilder: (context, index) {
          final entry = sortedEntries[index];
          final percent = (entry.value /
              sortedEntries.fold(0, (sum, e) => sum + e.value) *
              100)
              .toStringAsFixed(1);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    entry.key,
                    style: Tok.body.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    entry.value.toString(),
                    style: Tok.bodySm.copyWith(color: Tok.textHi),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Tok.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor:
                          entry.value / sortedEntries.first.value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Tok.brand,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$percent%',
                        style: Tok.bodySm.copyWith(
                            color: Tok.textLo, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReportStats {
  final int total, pending, awaitingDocs, submitted, assigned, completed, issued;
  final Map<String, int> barangayDistribution;

  const _ReportStats({
    required this.total,
    required this.pending,
    required this.awaitingDocs,
    required this.submitted,
    required this.assigned,
    required this.completed,
    required this.issued,
    required this.barangayDistribution,
  });
}