import 'package:flutter/material.dart';
import 'package:my_app/services/api_service.dart';

class FieldAnalysisScreen extends StatefulWidget {
  final Map<String, dynamic> field;
  const FieldAnalysisScreen({super.key, required this.field});

  @override
  State<FieldAnalysisScreen> createState() => _FieldAnalysisScreenState();
}

class _FieldAnalysisScreenState extends State<FieldAnalysisScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic>? results;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    setState(() { loading = true; error = null; results = null; });
    try {
      final rawCoords = widget.field['points'] ?? widget.field['polygon'] ?? widget.field['coordinates'];
      final coords = (rawCoords as List).map((p) => {'lat': p['lat'] ?? p['latitude'], 'lng': p['lng'] ?? p['longitude']}).toList();
      final res = await ApiService.fetchNdviSeries(coords);
      final carbon = await ApiService.calculateCarbon(coords);
      setState(() {
        results = {'ndviSeries': res['series'] ?? [], 'carbon': carbon};
      });
    } catch (e) {
      setState(() { error = e.toString(); });
    } finally {
      setState(() { loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.field['name'] ?? 'Field Analysis')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text('Error: $error'))
                : SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Area (ha): ${(widget.field['area_m2'] ?? 0) / 10000}'),
                      const SizedBox(height: 12),
                      Text('Carbon result: ${results?['carbon'] ?? {}}'),
                      const SizedBox(height: 12),
                      const Text('NDVI Samples (latest):', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if ((results?['ndviSeries'] as List).isEmpty)
                        const Text('No NDVI data')
                      else
                        ...((results?['ndviSeries'] as List).take(10).map((e) => ListTile(title: Text(e['date'] ?? e['timestamp'] ?? ''), subtitle: Text('NDVI: ${e['ndvi'] ?? e['value']}'))))
                    ]),
                  ),
      ),
    );
  }
}
