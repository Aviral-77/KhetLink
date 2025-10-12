import 'package:flutter/material.dart';
import 'package:my_app/services/farm_storage.dart';
import 'package:my_app/screens/carbon_details_screen.dart';

class CarbonCalculatorScreen extends StatefulWidget {
  const CarbonCalculatorScreen({super.key});

  @override
  State<CarbonCalculatorScreen> createState() => _CarbonCalculatorScreenState();
}

class _CarbonCalculatorScreenState extends State<CarbonCalculatorScreen> {
  List<Map<String, dynamic>> _fields = [];
  Map<String, dynamic>? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    setState(() { _loading = true; });
    final list = await FarmStorage.loadAllFields();
    setState(() {
      _fields = list;
      if (_fields.isNotEmpty) _selected = _fields.first;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carbon Credits Calculator'), backgroundColor: Colors.green),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: Icon(Icons.eco, size: 64, color: Colors.green)),
                    const SizedBox(height: 12),
                    const Text('Calculate carbon credits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Get an estimate of carbon sequestration and awarded credits for your field.'),
                    const SizedBox(height: 16),
                    _loading ? const LinearProgressIndicator() : DropdownButtonFormField<Map<String,dynamic>>(
                      isExpanded: true,
                      value: _selected,
                      items: _fields.map((f) => DropdownMenuItem(value: f, child: Text(f['name'] ?? f['id']))).toList(),
                      onChanged: (v) => setState(() => _selected = v),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selected == null ? null : () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => CarbonDetailsScreen(field: _selected!)));
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Padding(padding: EdgeInsets.symmetric(vertical: 14.0), child: Text('Calculate')),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Align(alignment: Alignment.centerLeft, child: Text('My Plans', style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            Card(child: Padding(padding: const EdgeInsets.all(12.0), child: Row(children: const [Icon(Icons.save), SizedBox(width: 12), Expanded(child: Text('Your saved carbon plan will appear here'))]))),
          ],
        ),
      ),
    );
  }
}
