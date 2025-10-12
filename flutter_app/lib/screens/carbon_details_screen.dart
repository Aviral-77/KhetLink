import 'package:flutter/material.dart';
import 'package:my_app/services/api_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class CarbonDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> field;
  const CarbonDetailsScreen({super.key, required this.field});

  @override
  State<CarbonDetailsScreen> createState() => _CarbonDetailsScreenState();
}

class _CarbonDetailsScreenState extends State<CarbonDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool loading = true;
  Map<String, dynamic>? satellite;
  Map<String, dynamic>? awarded;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    try {
      final coords = widget.field['points'] ?? widget.field['polygon'] ?? widget.field['coordinates'];
      final data = await ApiService.fetchNdviSeries((coords as List).map((p) => {'lat': p['lat'] ?? p['latitude'], 'lng': p['lng'] ?? p['longitude']}).toList());
      final carbon = await ApiService.calculateCarbon((coords as List).map((p) => {'lat': p['lat'] ?? p['latitude'], 'lng': p['lng'] ?? p['longitude']}).toList());
      setState(() {
        satellite = data;
        awarded = carbon;
      });
    } catch (e) {
      setState(() {
        satellite = null;
        awarded = null;
      });
    } finally {
      setState(() => loading = false);
    }
  }

  Widget _summaryIcon(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  // Helper to safely parse and format numeric values from API maps
  String _formatNum(dynamic v, {int digits = 2}) {
    if (v == null) return '--';
    try {
      if (v is num) return v.toStringAsFixed(digits);
      final parsed = double.parse(v.toString());
      return parsed.toStringAsFixed(digits);
    } catch (_) {
      return v.toString();
    }
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    try { return double.parse(v.toString()); } catch (_) { return null; }
  }

  Widget _fieldSummaryPanel() {
    final field = widget.field;
    final area = field['area_ha'] ?? (field['area_m2'] != null ? field['area_m2'] / 10000.0 : null);

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _summaryIcon('Target Carbon', awarded?['carbon_tons']?.toStringAsFixed(2) ?? '--', Icons.eco, Colors.green),
            _summaryIcon('Plan', field['plan'] ?? 'MRV plan', Icons.assignment, Colors.blueGrey),
            _summaryIcon('Field Size', area != null ? '${area.toStringAsFixed(2)} ha' : '--', Icons.crop_square, Colors.orange),
            _summaryIcon('Crop', field['crop'] ?? 'Unknown', Icons.grass, Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _satelliteTab() {
    final series = satellite?['series'] ?? [];
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        ExpansionTile(
          title: const Text('NDVI Time Series', style: TextStyle(fontWeight: FontWeight.bold)),
          initiallyExpanded: true,
          children: [
            if (series.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No NDVI data available.'),
              )
            else
              ...series.map((e) => ListTile(
                    leading: const Icon(Icons.terrain, color: Colors.green),
                    title: Text('Date: ${e['date'] ?? e['timestamp'] ?? '-'}'),
                    subtitle: Text('NDVI: ${(e['ndvi'] ?? e['value'] ?? 0).toStringAsFixed(3)}'),
                  )),
          ],
        ),
        ExpansionTile(
          title: const Text('Carbon Summary', style: TextStyle(fontWeight: FontWeight.bold)),
          initiallyExpanded: true,
          children: [
            ListTile(
              leading: const Icon(Icons.cloud, color: Colors.teal),
              title: const Text('Carbon'),
              subtitle: Text('${awarded?['carbon_tons'] ?? '-'} tons'),
            ),
            ListTile(
              leading: const Icon(Icons.area_chart, color: Colors.orange),
              title: const Text('Area'),
              subtitle: Text('${awarded?['area_m2'] != null ? (awarded!['area_m2'] / 10000).toStringAsFixed(2) : '-'} ha'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _awardedTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        ExpansionTile(
          title: const Text('Awarded Credits', style: TextStyle(fontWeight: FontWeight.bold)),
          initiallyExpanded: true,
          children: [
            // Show credits with fallbacks
            ListTile(
              leading: const Icon(Icons.credit_score, color: Colors.purple),
              title: const Text('Credits (tons)'),
              subtitle: Text(awarded == null ? '-' : _formatNum(awarded?['credits'] ?? awarded?['carbon_tons'] ?? awarded?['carbon'] ?? '-')),
            ),
            // Show credit rate, searching several possible keys returned by the API
            ListTile(
              leading: const Icon(Icons.attach_money, color: Colors.green),
              title: const Text('Credit Rate'),
              subtitle: Text(awarded == null
                  ? '-'
                  : '${_formatNum(awarded?['rate_inr'] ?? awarded?['rate'] ?? awarded?['credit_rate'] ?? awarded?['price_per_ton'] ?? '-')} INR / ton'),
            ),
            // Derived estimated value if both credits and rate available
            if (awarded != null)
              Builder(builder: (_) {
                final creditsVal = _asDouble(awarded?['credits'] ?? awarded?['carbon_tons'] ?? awarded?['carbon']);
                final rateVal = _asDouble(awarded?['rate_inr'] ?? awarded?['rate'] ?? awarded?['credit_rate'] ?? awarded?['price_per_ton']);
                if (creditsVal != null && rateVal != null) {
                  final est = creditsVal * rateVal;
                  return ListTile(
                    leading: const Icon(Icons.account_balance_wallet, color: Colors.brown),
                    title: const Text('Estimated Value'),
                    subtitle: Text('${est.toStringAsFixed(2)} INR'),
                  );
                }
                return const SizedBox.shrink();
              }),
          ],
        ),
        ExpansionTile(
          title: const Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Column(children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
                  child: const Text('Verify Credits'),
                  onPressed: () {
                    // TODO: Implement verify logic
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
                  child: const Text('Download Report'),
                  onPressed: () {
                    // TODO: Implement report download logic
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Data'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
                  onPressed: _loadData,
                ),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.field['name'] ?? 'Carbon Details'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          _fieldSummaryPanel(),
          Container(
            color: Colors.grey.shade200,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.green,
              tabs: const [
                Tab(text: 'Satellite Data'),
                Tab(text: 'Awarded Credits'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                loading
                    ? const Center(child: CircularProgressIndicator())
                    : _satelliteTab(),
                loading
                    ? const Center(child: CircularProgressIndicator())
                    : _awardedTab(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
              child: const Text('Save Carbon Data'),
              onPressed: () {
                // TODO: Implement save carbon data logic
              },
            ),
          ),
        ],
      ),
    );
  }
}
