import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_app/screens/farm_mapping_screen.dart';
import 'package:my_app/services/farm_storage.dart';


class MapMyFarmScreen extends StatefulWidget {
  const MapMyFarmScreen({super.key});

  @override
  State<MapMyFarmScreen> createState() => _MapMyFarmScreenState();
}

class _MapMyFarmScreenState extends State<MapMyFarmScreen> {
  String? _selectedField;

  final List<String> _fields = [
    "Gautam Buddha Nagar field",
    "Noida Extension farm",
    "New Field",
  ];

  List<Map<String, dynamic>> _savedFields = [];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final list = await FarmStorage.loadAllFields();
    if (list.isNotEmpty) {
      setState(() {
        _savedFields = list;
        _fields.clear();
        _fields.addAll(list.map((e) => e['name'] ?? e['id']).cast<String>());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Map My Farm"), backgroundColor: Colors.green),
      body: Column(
        children: [
          const SizedBox(height: 16),
          const Text("Measure your field", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              value: _selectedField,
              hint: const Text("Select field"),
              items: _fields.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedField = val;
                });
              },
            ),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            icon: const Icon(Icons.map),
            label: const Text("Map my farm"),
            onPressed: _selectedField == null
                ? null
                : () async {
                    final added = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FarmMappingScreen(fieldName: _selectedField!),
                      ),
                    );
                    if (added == true) {
                      await _loadSaved();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Field added')));
                    }
                  },
          ),

          const Divider(height: 32),

          const Text("Saved Measurements", style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
