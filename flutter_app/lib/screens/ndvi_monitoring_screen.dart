import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:my_app/api_service.dart';
import 'package:my_app/services/farm_storage.dart';
import 'package:my_app/screens/field_analysis_screen.dart';
import 'package:my_app/screens/carbon_calculator_screen.dart';

class NDVIMonitoringScreen extends StatefulWidget {
  const NDVIMonitoringScreen({super.key});

  @override
  State<NDVIMonitoringScreen> createState() => _NDVIMonitoringScreenState();
}

class _NDVIMonitoringScreenState extends State<NDVIMonitoringScreen> {
  bool loading = false;
  String? error;
  List<dynamic> ndviSeries = [];
  List<Map<String, dynamic>> fields = [];
  Map<String, dynamic>? selectedField;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final list = await FarmStorage.loadAllFields();
      setState(() {
        fields = list;
        if (fields.isNotEmpty) selectedField = fields.first;
      });
      if (selectedField != null) await _fetchForSelected();
    } catch (e) {
      setState(() => error = 'Failed to load saved fields: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _fetchForSelected() async {
    if (selectedField == null) return;
    setState(() {
      loading = true;
      error = null;
      ndviSeries = [];
    });
    try {
      final rawCoords = selectedField!['points'] ??
          selectedField!['polygon'] ??
          selectedField!['coordinates'];

      if (rawCoords == null || (rawCoords is List && rawCoords.isEmpty)) {
        setState(() => error = 'Selected field has no coordinates.');
        return;
      }

      final coords = (rawCoords as List).map((p) {
        if (p is Map) {
          return {
            'lat': p['lat'] ?? p['latitude'],
            'lng': p['lng'] ?? p['longitude']
          };
        }
        return p;
      }).toList();

      final data = await ApiService.fetchNdviSeries(coords);
      setState(() {
        ndviSeries = data['series'] ?? [];
      });
    } catch (e) {
      setState(() => error = 'NDVI fetch failed: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  double _avgNDVI() {
    if (ndviSeries.isEmpty) return 0;
    return ndviSeries
            .map((e) => (e['ndvi'] ?? e['value'] ?? 0).toDouble())
            .reduce((a, b) => a + b) /
        ndviSeries.length;
  }

  double _maxNDVI() {
    if (ndviSeries.isEmpty) return 0;
    return ndviSeries
        .map((e) => (e['ndvi'] ?? e['value'] ?? 0).toDouble())
        .reduce((a, b) => a > b ? a : b);
  }

  double _minNDVI() {
    if (ndviSeries.isEmpty) return 0;
    return ndviSeries
        .map((e) => (e['ndvi'] ?? e['value'] ?? 0).toDouble())
        .reduce((a, b) => a < b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NDVI Monitoring')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // --- Field Selection ---
            Row(
              children: [
                Expanded(
                  child: DropdownButton<Map<String, dynamic>?>(
                    isExpanded: true,
                    value: selectedField,
                    hint: const Text('Select saved field'),
                    items: fields
                        .map((f) => DropdownMenuItem(
                              value: f,
                              child: Text(f['name'] ?? f['id']),
                            ))
                        .toList(),
                    onChanged: (v) async {
                      setState(() => selectedField = v);
                      // Do not auto-fetch; wait for explicit Calculate button
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadFields,
                )
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CarbonCalculatorScreen()));
              },
              child: const Text('Calculate carbon credits'),
            ),
            const SizedBox(height: 12),

            // --- Main Content ---
            if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (error != null)
              Expanded(child: Center(child: Text(error!)))
            else if (ndviSeries.isEmpty)
              Expanded(
                  child: Center(
                      child: Text(fields.isEmpty
                          ? 'No saved fields found.'
                          : 'No NDVI data available for this field.')))
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("NDVI Time Series",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),

                      // --- Summary Cards ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSummaryCard("Avg NDVI", _avgNDVI(), Colors.blue),
                          _buildSummaryCard("Max NDVI", _maxNDVI(), Colors.green),
                          _buildSummaryCard("Min NDVI", _minNDVI(), Colors.red),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // --- Line Chart ---
                      SizedBox(height: 250, child: _buildChart()),
                      const SizedBox(height: 20),

                      // --- NDVI List ---
                      const Text("NDVI Records",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildList(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, double value, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value.toStringAsFixed(3),
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    final formatter = DateFormat('dd MMM');
    final spots = <FlSpot>[];
    for (int i = 0; i < ndviSeries.length; i++) {
      final item = ndviSeries[i];
      final ndviValue = (item['ndvi'] ?? item['value'] ?? 0).toDouble();
      spots.add(FlSpot(i.toDouble(), ndviValue));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= ndviSeries.length)
                    return const SizedBox.shrink();
                  final date = ndviSeries[index]['date'] ??
                      ndviSeries[index]['timestamp'] ??
                      '';
                  return Text(formatter.format(DateTime.parse(date)),
                      style: const TextStyle(fontSize: 10));
                }),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 35),
          ),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            belowBarData:
                BarAreaData(show: true, color: Colors.green.withOpacity(0.3)),
            dotData: const FlDotData(show: true),
            spots: spots,
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ndviSeries.length,
      itemBuilder: (context, index) {
        final item = ndviSeries[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.terrain, color: Colors.green),
            title: Text('Date: ${item['date'] ?? item['timestamp'] ?? index}'),
            subtitle: Text(
                'NDVI: ${item['ndvi']?.toStringAsFixed(3) ?? '-'} | Carbon: ${item['carbon_tons'] ?? '-'} tons'),
          ),
        );
      },
    );
  }
}
