import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fl_chart/fl_chart.dart';
import '../admin_theme.dart';

class OverviewView extends StatefulWidget {
  const OverviewView({super.key});

  @override
  State<OverviewView> createState() => _OverviewViewState();
}

class _OverviewViewState extends State<OverviewView> {
  bool _isEditingStation = false;
  LatLng _stationPos = const LatLng(8.5083, 125.9754);
  bool _isLoadingPos = true;

  @override
  void initState() {
    super.initState();
    _loadStationPosition();
  }

  Future<void> _loadStationPosition() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('fire_station')
          .get();
      if (doc.exists) {
        final d = doc.data();
        if (d != null) {
          setState(() => _stationPos = LatLng(d['lat'], d['lng']));
        }
      }
    } catch (e) {
      debugPrint('Error loading station pos: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPos = false);
    }
  }

  Future<void> _saveStationPosition() async {
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('fire_station')
          .set({
        'lat': _stationPos.latitude,
        'lng': _stationPos.longitude,
        'updated_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fire station position saved'),
            backgroundColor: Tok.ok,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Tok.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPos) {
      return Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Tok.textLo),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('barangays').snapshots(),
      builder: (context, barangaySnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('inspection_requests')
              .snapshots(),
          builder: (context, requestsSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, usersSnapshot) {
                final users = usersSnapshot.data?.docs ?? const [];
                final requests = requestsSnapshot.data?.docs ?? const [];

                final totalUsers = users.length;
                final activeInspectors = users
                    .where((d) =>
                (d.data() as Map<String, dynamic>)['role'] == 'Inspector')
                    .length;
                final pendingRequests = requests
                    .where((d) =>
                (d.data() as Map<String, dynamic>)['status'] ==
                    'pending_approval')
                    .length;

                // Heat-map circles
                final circles = <CircleMarker>[];
                final labels = <Marker>[];

                if (barangaySnapshot.hasData) {
                  final registered = <String, LatLng>{};
                  for (final doc in barangaySnapshot.data!.docs) {
                    final d = doc.data() as Map<String, dynamic>;
                    registered[d['name']] = LatLng(d['lat'], d['lng']);
                  }
                  final density = <String, int>{};
                  for (final doc in requests) {
                    final data = doc.data() as Map<String, dynamic>;
                    final b = data['barangay'];
                    if (b is String && registered.containsKey(b)) {
                      density[b] = (density[b] ?? 0) + 1;
                    }
                  }
                  density.forEach((brgy, count) {
                    final pos = registered[brgy];
                    if (pos == null) return;
                    final heat = count <= 5
                        ? Tok.danger
                        : (count <= 10 ? Tok.warn : Tok.ok);
                    circles.add(CircleMarker(
                      point: pos,
                      color: heat.withValues(alpha: 0.12),
                      useRadiusInMeter: true,
                      radius: 500 + (count * 120).toDouble(),
                    ));
                    circles.add(CircleMarker(
                      point: pos,
                      color: heat.withValues(alpha: 0.35),
                      useRadiusInMeter: true,
                      radius: 300 + (count * 60).toDouble(),
                    ));
                    labels.add(Marker(
                      point: pos,
                      width: 140,
                      height: 90,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Tok.bg.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(Tok.rSm),
                              border: Border.all(
                                  color: heat.withValues(alpha: 0.6)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  brgy,
                                  style: TextStyle(
                                    color: Tok.textHi,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  '$count requests',
                                  style: TextStyle(
                                    color: heat,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(Icons.account_balance_rounded,
                              color: heat, size: 18),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ));
                  });
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MetricsBar(
                        totalUsers: totalUsers,
                        activeInspectors: activeInspectors,
                        pendingRequests: pendingRequests,
                      ),
                      const SizedBox(height: 24),

                      LayoutBuilder(
                        builder: (context, c) {
                          final wide = c.maxWidth >= 1000;
                          final chart = Panel(
                            title: 'Inspection distribution',
                            subtitle: 'Current workload by workflow stage',
                            child: SizedBox(
                              height: 320,
                              child: _buildInspectionChart(requestsSnapshot),
                            ),
                          );
                          final feed = Panel(
                            title: 'Activity',
                            subtitle: 'Most recent inspection events',
                            padded: false,
                            child: SizedBox(
                              height: 320,
                              child: _buildActivityFeed(requestsSnapshot),
                            ),
                          );
                          if (wide) {
                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(flex: 3, child: chart),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 2, child: feed),
                                ],
                              ),
                            );
                          }
                          return Column(
                            children: [
                              chart,
                              const SizedBox(height: 16),
                              feed,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      Panel(
                        title: 'Barangay density & station location',
                        subtitle: _isEditingStation
                            ? 'Tap the map to reposition the fire station'
                            : 'Heat map of inspection requests by barangay',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isEditingStation)
                              TextButton(
                                onPressed: () =>
                                    setState(() => _isEditingStation = false),
                                style: TextButton.styleFrom(
                                    foregroundColor: Tok.textMid),
                                child: const Text('Cancel',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                if (_isEditingStation) _saveStationPosition();
                                setState(
                                        () => _isEditingStation = !_isEditingStation);
                              },
                              icon: Icon(
                                _isEditingStation
                                    ? Icons.check_rounded
                                    : Icons.edit_location_alt_outlined,
                                size: 16,
                              ),
                              label: Text(_isEditingStation
                                  ? 'Save position'
                                  : 'Edit station'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isEditingStation
                                    ? Tok.ok
                                    : Tok.surfaceAlt,
                                foregroundColor: Tok.textHi,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(Tok.rMd),
                                  side: BorderSide(color: Tok.border),
                                ),
                                textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        padded: false,
                        child: SizedBox(
                          height: 440,
                          child: ClipRRect(
                            borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(Tok.rLg)),
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter:
                                const LatLng(8.5106, 125.9793),
                                initialZoom: 13.5,
                                onTap: (_, latlng) {
                                  if (_isEditingStation) {
                                    setState(() => _stationPos = latlng);
                                  }
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.pyra.check',
                                ),
                                CircleLayer(circles: circles),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _stationPos,
                                      width: 90,
                                      height: 70,
                                      child: Column(
                                        mainAxisAlignment:
                                        MainAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Tok.bg
                                                  .withValues(alpha: 0.9),
                                              borderRadius:
                                              BorderRadius.circular(
                                                  Tok.rSm),
                                              border: _isEditingStation
                                                  ? Border.all(color: Tok.warn)
                                                  : Border.all(
                                                  color: Tok.border),
                                            ),
                                            child: Text(
                                              _isEditingStation
                                                  ? 'Tap to move'
                                                  : 'Fire Station',
                                              style: TextStyle(
                                                color: Tok.textHi,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const Icon(
                                            Icons.local_fire_department_rounded,
                                            color: Tok.brand,
                                            size: 26,
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                MarkerLayer(markers: labels),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInspectionChart(AsyncSnapshot<QuerySnapshot> snapshot) {
    if (!snapshot.hasData) {
      return Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Tok.textLo),
      );
    }

    final counts = <String, int>{
      'pending': 0,
      'approved': 0,
      'assigned': 0,
      'completed': 0
    };
    for (final doc in snapshot.data!.docs) {
      final status = ((doc.data() as Map)['status'] ?? 'pending').toString();
      if (status.contains('pending')) {
        counts['pending'] = counts['pending']! + 1;
      } else if (status.contains('approved')) {
        counts['approved'] = counts['approved']! + 1;
      } else if (status.contains('assigned')) {
        counts['assigned'] = counts['assigned']! + 1;
      } else if (status.contains('completed')) {
        counts['completed'] = counts['completed']! + 1;
      }
    }

    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final sections = <PieChartSectionData>[
      _sec(counts['pending']!, Tok.stPending, 'Pending'),
      _sec(counts['approved']!, Tok.stApproved, 'Approved'),
      _sec(counts['assigned']!, Tok.stAssigned, 'Assigned'),
      _sec(counts['completed']!, Tok.stCompleted, 'Completed'),
    ];

    return Row(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 74,
                  startDegreeOffset: -90,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$total', style: Tok.num),
                  const SizedBox(height: 2),
                  Text('TOTAL', style: Tok.label),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _legendRow('Pending', Tok.stPending, counts['pending']!),
            _legendRow('Approved', Tok.stApproved, counts['approved']!),
            _legendRow('Assigned', Tok.stAssigned, counts['assigned']!),
            _legendRow('Completed', Tok.stCompleted, counts['completed']!),
          ],
        ),
      ],
    );
  }

  PieChartSectionData _sec(int value, Color color, String title) =>
      PieChartSectionData(
        value: value.toDouble(),
        color: color,
        radius: 46,
        title: value == 0 ? '' : '$value',
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        titlePositionPercentageOffset: 0.6,
      );

  Widget _legendRow(String label, Color color, int count) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(label,
              style: Tok.bodySm.copyWith(color: Tok.textMid)),
        ),
        Text('$count', style: Tok.numSm),
      ],
    ),
  );

  Widget _buildActivityFeed(AsyncSnapshot<QuerySnapshot> snapshot) {
    if (!snapshot.hasData) {
      return Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Tok.textLo),
      );
    }
    final docs = snapshot.data!.docs.take(12).toList();
    if (docs.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        label: 'No recent activity',
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
        final data = docs[index].data() as Map<String, dynamic>;
        final property = (data['property_name'] ?? 'General update').toString();
        final status = (data['status'] ?? 'pending').toString();
        final color = _statusColor(status);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Tok.rSm),
                ),
                child: Icon(_statusIcon(status), size: 13, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tok.body.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      status.replaceAll('_', ' '),
                      style: Tok.bodySm.copyWith(
                        color: Tok.textLo,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    if (status.contains('pending')) return Tok.stPending;
    if (status.contains('approved')) return Tok.stApproved;
    if (status.contains('assigned')) return Tok.stAssigned;
    if (status.contains('completed')) return Tok.stCompleted;
    return Tok.textLo;
  }

  IconData _statusIcon(String status) {
    if (status.contains('pending')) return Icons.hourglass_top_rounded;
    if (status.contains('approved')) return Icons.check_circle_outline_rounded;
    if (status.contains('assigned')) return Icons.person_pin_circle_outlined;
    if (status.contains('completed')) return Icons.verified_outlined;
    return Icons.info_outline_rounded;
  }
}

class _MetricsBar extends StatelessWidget {
  final int totalUsers;
  final int activeInspectors;
  final int pendingRequests;

  const _MetricsBar({
    required this.totalUsers,
    required this.activeInspectors,
    required this.pendingRequests,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tok.surface,
        borderRadius: BorderRadius.circular(Tok.rLg),
        border: Border.all(color: Tok.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Total citizens',
                value: '$totalUsers',
                hint: 'Registered accounts',
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: Tok.borderSoft),
            Expanded(
              child: _Metric(
                label: 'On-field inspectors',
                value: '$activeInspectors',
                hint: 'Currently active roles',
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: Tok.borderSoft),
            Expanded(
              child: _Metric(
                label: 'New requests',
                value: '$pendingRequests',
                hint: 'Awaiting approval',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  const _Metric({
    required this.label,
    required this.value,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(), style: Tok.label),
          const SizedBox(height: 8),
          Text(value, style: Tok.num),
          const SizedBox(height: 4),
          Text(
            hint,
            style: Tok.bodySm.copyWith(color: Tok.textLo, fontSize: 11),
          ),
        ],
      ),
    );
  }
}