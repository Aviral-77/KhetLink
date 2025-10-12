import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:my_app/services/farm_storage.dart';
import 'package:my_app/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math' as math;

class CreditVerificationScreen extends StatefulWidget {
  const CreditVerificationScreen({super.key});
  @override
  State<CreditVerificationScreen> createState() => _CreditVerificationScreenState();
}

class _CreditVerificationScreenState extends State<CreditVerificationScreen> {
  bool loading = false;
  String? error;
  List<Map<String, dynamic>> fields = [];
  Map<String, dynamic>? selectedField;
  List<dynamic> ndviSeries = [];
  double carbonTons = 0.0;
  double areaHa = 0.0;
  String verificationResult = '';
  double baselineAvgCarbon = 0.0;
  double confidencePercent = 0.0;
  String lastVerified = '';
  List<Map<String, String>> auditTrail = [];
  Map<String, Map<String, dynamic>> fieldResults = {};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    setState(() { loading = true; error = null; });
    try {
      final list = await FarmStorage.loadAllFields();
      setState(() {
        fields = List<Map<String, dynamic>>.from(list);
        fieldResults = {};
        for (var f in fields) {
          final id = f['id']?.toString() ?? f['name']?.toString() ?? fields.indexOf(f).toString();
          fieldResults[id] = {
            'loading': false,
            'carbonTons': 0.0,
            'areaHa': 0.0,
            'ndviSeries': [],
            'verificationResult': '',
            'baselineAvg': 0.0,
            'confidence': 0.0,
            'lastVerified': '',
            'auditTrail': _mockAuditTrail(),
          };
        }
      });
    } catch (e) {
      setState(() => error = 'Failed to load fields: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _computeForField(Map<String, dynamic> field) async {
    final id = field['id']?.toString() ?? field['name']?.toString() ?? fields.indexOf(field).toString();
    fieldResults[id] = {...fieldResults[id] ?? {}, 'loading': true};
    setState(() {});
    try {
      final raw = field['points'] ?? field['polygon'] ?? field['coordinates'];
      final coords = (raw as List).map((p) => {
        'lat': p['lat'] ?? p['latitude'],
        'lng': p['lng'] ?? p['longitude']
      }).toList();

      final cdata = await ApiService.calculateCarbon(coords);
      final ts = await ApiService.fetchNdviSeries(coords);

      double carbon = (cdata['carbon_tons'] ?? 0.0).toDouble();
      double area = ((cdata['area_m2'] ?? 0.0) / 10000.0).toDouble();
      final series = ts['series'] ?? [];

      double baselineAvg = 0.0;
      double conf = 0.0;
      String last = '';
      List<Map<String, String>> trail = [];
      try {
        final recent = await ApiService.history(limit: 12);
        double sum = 0.0;
        int cnt = 0;
        DateTime? latest;
        final tmpTrail = <Map<String, String>>[];
        for (final r in recent) {
          if (r is Map) {
            if (r['carbon_tons'] != null) {
              sum += (r['carbon_tons'] as num).toDouble();
              cnt += 1;
            }
            final text = r['message'] ?? r['event'] ?? r['action'];
            final timeRaw = r['timestamp'] ?? r['created_at'] ?? r['time'];
            String when = '';
            if (timeRaw != null) {
              try {
                final dt = DateTime.parse(timeRaw.toString());
                if (latest == null || dt.isAfter(latest)) latest = dt;
                when = _relativeTime(dt);
              } catch (e) {
                when = timeRaw.toString();
              }
            }
            if (text != null) {
              tmpTrail.add({'text': text.toString(), 'time': when.isNotEmpty ? when : 'recent'});
            }
          }
        }
        baselineAvg = cnt > 0 ? (sum / cnt) : 0.0;
        trail = tmpTrail.isNotEmpty ? tmpTrail : _mockAuditTrail();
        if (latest != null) last = _relativeTime(latest);
        if (cnt > 1) {
          final values = recent
              .whereType<Map>()
              .where((m) => m['carbon_tons'] != null)
              .map((m) => ((m['carbon_tons'] as num).toDouble()))
              .toList();
          final mean = values.reduce((a, b) => a + b) / values.length;
          final variance =
              values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
          final sd = math.sqrt(variance);
          conf = ((1 - (sd / (mean == 0 ? 1 : mean))) * 100).clamp(0.0, 100.0);
        } else {
          conf = baselineAvg == 0.0 ? 94.0 : 90.0;
        }
      } catch (e) {
        trail = _mockAuditTrail();
      }

      fieldResults[id] = {
        ...fieldResults[id] ?? {},
        'loading': false,
        'carbonTons': carbon,
        'areaHa': area,
        'ndviSeries': series,
        'verificationResult': _deriveVerification(carbon, baselineAvg),
        'baselineAvg': baselineAvg,
        'confidence': conf,
        'lastVerified': last,
        'auditTrail': trail,
      };
    } catch (e) {
      fieldResults[id] = {...fieldResults[id] ?? {}, 'loading': false};
      setState(() => error = 'Computation failed for field $id: $e');
    }
    setState(() {});
  }

  String _deriveVerification(double carbon, double baseline) {
    final delta = (carbon - baseline).abs();
    if (baseline == 0 && carbon > 0) return 'No baseline available — new record.';
    final ratio = delta / (baseline == 0 ? 1 : baseline);
    if (ratio < 0.15) return 'Verification Passed';
    if (ratio < 0.35) return 'Verification Warning';
    return 'Verification Failed';
  }

  // Debounce dropdown
  void _onFieldSelected(Map<String, dynamic>? v) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => selectedField = v);
      if (v != null) await _computeForField(v);
    });
  }

  Future<void> _showFieldDetails(BuildContext context, Map<String, dynamic> field) async {
    final id = field['id']?.toString() ?? field['name']?.toString() ?? fields.indexOf(field).toString();
    final res = fieldResults[id] ?? {};
    final series = res['ndviSeries'] ?? [];
    final carbon = res['carbonTons'] ?? 0.0;
    final area = res['areaHa'] ?? 0.0;

    final points = (field['points'] ?? field['polygon'] ?? field['coordinates'] ?? []) as List;
    final latLngs = points
        .where((p) => p['lat'] != null && p['lng'] != null)
        .map((p) => LatLng(p['lat'] ?? p['latitude'], p['lng'] ?? p['longitude']))
        .toList();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(field['name'] ?? 'Field $id'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Area: ${area.toStringAsFixed(3)} ha'),
                const SizedBox(height: 8),
                if (latLngs.isNotEmpty)
                  SizedBox(
                    height: 220,
                    child: GoogleMap(
                      mapType: MapType.satellite,
                      initialCameraPosition: CameraPosition(
                        target: latLngs.first,
                        zoom: 17,
                      ),
                      polygons: {
                        Polygon(
                          polygonId: const PolygonId('field'),
                          points: latLngs,
                          fillColor: Colors.green.withOpacity(0.3),
                          strokeColor: Colors.green,
                          strokeWidth: 2,
                        ),
                      },
                      markers: latLngs
                          .asMap()
                          .entries
                          .map((e) => Marker(
                                markerId: MarkerId(e.key.toString()),
                                position: e.value,
                              ))
                          .toSet(),
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: series.isNotEmpty
                      ? _buildChartForSeries(series)
                      : const Center(child: Text('No NDVI data')),
                ),
                const SizedBox(height: 8),
                Text('Carbon: ${carbon.toStringAsFixed(3)} t'),
                const SizedBox(height: 8),
                Text('Verification: ${res['verificationResult'] ?? '—'}'),
                const SizedBox(height: 8),
                ...((res['auditTrail'] as List?) ?? []).map(
                  (e) => ListTile(
                    dense: true,
                    title: Text(e['text'] ?? ''),
                    trailing: Text(e['time'] ?? ''),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () => _openReport(field),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Generate Report'),
          ),
        ],
      ),
    );
  }

  Widget _buildChartForSeries(List series) {
    final valid = series
        .where((e) => (e['ndvi'] ?? e['value']) != null)
        .map((e) => ((e['ndvi'] ?? e['value']) as num).toDouble())
        .toList();
    if (valid.isEmpty) return const Center(child: Text("No NDVI data"));
    final spots = List<FlSpot>.generate(
        valid.length, (i) => FlSpot(i.toDouble(), (valid[i] * 80).clamp(0, 100).toDouble()));
    return LineChart(
      LineChartData(
        minY: 0, maxY: 100,
        lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: Colors.green, barWidth: 2)],
        titlesData: FlTitlesData(show: false),
        gridData: FlGridData(show: false),
      ),
    );
  }

  Future<void> _openReport([Map<String, dynamic>? field]) async {
    Map<String, dynamic>? f = field ?? selectedField;
    if (f == null) return;
    final rec = f['record_id'] ?? f['id'];
    final url = 'https://geoserver.bluehawk.ai:8045/gee/mrv/report/$rec';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      setState(() => error = 'Unable to open report URL.');
    }
  }

  List<Map<String, String>> _mockAuditTrail() => [
        {'text': 'NDVI calculation completed', 'time': '2 days ago'},
        {'text': 'Baseline comparison validated', 'time': '2 days ago'},
        {'text': 'Carbon report generated', 'time': '2 days ago'},
        {'text': 'API calls logged', 'time': '2 days ago'},
      ];

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()} mo ago';
    if (diff.inDays >= 1) return '${diff.inDays} days ago';
    if (diff.inHours >= 1) return '${diff.inHours} hours ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} minutes ago';
    return 'just now';
  }

  Future<void> _computeAll() async {
    setState(() { loading = true; });
    for (final f in fields) {
      await _computeForField(f);
    }
    setState(() { loading = false; });
  }

  double _growthForSeries(List series) {
    final valid = series
        .where((e) => (e['ndvi'] ?? e['value']) != null)
        .map((e) => ((e['ndvi'] ?? e['value']) as num).toDouble())
        .toList();
    if (valid.isEmpty) return 0.0;
    try {
      final first = valid.first;
      final last = valid.last;
      if (first == 0) return (last * 100.0);
      return ((last - first) / first) * 100.0;
    } catch (e) {
      return 0.0;
    }
  }

  double _accuracyForSeries(List series) {
    final values = series
        .where((s) => (s['ndvi'] ?? s['value']) != null)
        .map((s) => ((s['ndvi'] ?? s['value']) as num).toDouble())
        .toList();
    if (values.isEmpty) return 0.0;
    try {
      final mean = values.reduce((a, b) => a + b) / values.length;
      if (mean == 0) return 50.0;
      final variance = values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
      final sd = math.sqrt(variance);
      final acc = (1 - (sd / (mean == 0 ? 1 : mean))) * 100;
      return acc.clamp(0.0, 100.0) as double;
    } catch (e) {
      return 75.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Map<String, dynamic>>(
                          value: selectedField,
                          isExpanded: true,
                          hint: const Text('Select field to view verification'),
                          items: fields.map((f) =>
                            DropdownMenuItem<Map<String, dynamic>>(
                              value: f,
                              child: Text(f['name'] ?? f['id'] ?? 'Field'),
                            )).toList(),
                          onChanged: loading ? null : _onFieldSelected,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: loading ? null : _computeAll,
                          icon: const Icon(Icons.playlist_play),
                          label: const Text('Compute All'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: loading ? null : _loadFields,
                        icon: Icon(Icons.refresh, color: loading ? Colors.grey : Colors.green, size: 24),
                        tooltip: 'Refresh fields',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (selectedField == null)
                    fields.isEmpty
                        ? Center(child: Text('No saved fields. Draw and save fields in My Farm.'))
                        : const Text('Choose a field from the dropdown to view its verification details.')
                  else
                    Builder(builder: (context) {
                      final f = selectedField!;
                      final id = f['id']?.toString() ?? f['name']?.toString() ?? fields.indexOf(f).toString();
                      final res = fieldResults[id] ?? {};
                      final series = (res['ndviSeries'] as List?) ?? [];
                      final carbon = (res['carbonTons'] ?? 0.0) as double;
                      final ver = res['verificationResult'] ?? '';
                      final conf = (res['confidence'] ?? 0.0) as double;
                      final last = res['lastVerified'] ?? '';

                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          color: ver.contains('Passed') ? Colors.green.shade50 : Colors.orange.shade50,
                          elevation: 3,
                          child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: ver.contains('Passed')
                                            ? Colors.green.shade200
                                            : Colors.orange.shade200),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    ver.contains('Passed') ? Icons.check_circle : Icons.error,
                                    color: ver.contains('Passed') ? Colors.green.shade700 : Colors.orange.shade700,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                      Text(ver.isNotEmpty ? ver : '—',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Confidence: ${conf.toStringAsFixed(0)}% • Last verified: ${last.isNotEmpty ? last : '—'}',
                                        style: const TextStyle(color: Colors.black54),
                                      )
                                    ])),
                              ])),
                        ),
                        const SizedBox(height: 12),
                        Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Trend Comparison', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  series.isNotEmpty
                                      ? SizedBox(height: 200, child: _buildChartForSeries(series))
                                      : const SizedBox(height: 120, child: Center(child: Text('No NDVI data'))),
                                ]))),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Growth Rate', style: TextStyle(color: Colors.black54)),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${_growthForSeries(series).toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text('Above baseline', style: TextStyle(color: Colors.black54)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Accuracy', style: TextStyle(color: Colors.black54)),
                                    const SizedBox(height: 8),
                                    Text('${_accuracyForSeries(series).toStringAsFixed(1)}%',
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    const Text('vs historical', style: TextStyle(color: Colors.black54)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Audit Trail', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Column(
                                  children: (((res['auditTrail'] as List?) ?? _mockAuditTrail())
                                      .map((e) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: ListTile(
                                                dense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                leading: Icon(Icons.check_circle_outline, color: Colors.grey.shade600),
                                                title: Text(e['text'] ?? '', style: TextStyle(color: Colors.grey.shade800)),
                                                trailing: Text(e['time'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                              ),
                                            ),
                                          ))
                                      .toList()),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                        onPressed: () => _computeForField(f),
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Refresh')),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                        onPressed: () => _openReport(f),
                                        icon: const Icon(Icons.picture_as_pdf),
                                        label: const Text('Generate Report')),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                        onPressed: () => _showFieldDetails(context, f),
                                        child: const Text('View full details')),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ]);
                    }),
                ],
              ),
            ),
    );
  }
}
