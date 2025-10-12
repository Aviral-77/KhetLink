import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:my_app/services/farm_storage.dart';

class FieldSummary {
  final String id;
  final String name;
  final String crop;
  final String timestamp;
  final List<LatLng> points;
  FieldSummary({
    required this.id,
    required this.name,
    required this.crop,
    required this.timestamp,
    required this.points,
  });
}

class MyFarmScreen extends StatefulWidget {
  const MyFarmScreen({super.key});

  @override
  State<MyFarmScreen> createState() => _MyFarmScreenState();
}

class _MyFarmScreenState extends State<MyFarmScreen> {
  List<FieldSummary> _fields = [];
  FieldSummary? _selected;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    final list = await FarmStorage.loadAllFields();
    setState(() {
      _fields = list.map((e) => FieldSummary(
            id: e['id'],
            name: e['name'] ?? 'Field',
            crop: e['crop'] ?? '',
            timestamp: e['timestamp'] ?? '',
            points: (e['points'] as List)
                .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
                .toList(),
          )).toList();
      if (_fields.isNotEmpty) _selected = _fields.first;
    });
  }

  double _calculateArea(List<LatLng> points) {
    if (points.length < 3) return 0.0;
    double area = 0.0;
    for (int i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      area += (p1.longitude * p2.latitude) - (p2.longitude * p1.latitude);
    }
    double areaSqMeters = area.abs() / 2 * 111139 * 111139;
    return areaSqMeters / 4046.86; // convert to acres
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: true,
        titleSpacing: 0,
        title: Row(
          children: [
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<FieldSummary?>(
                  isExpanded: true,
                  value: _selected,
                  hint: const Text('Select Field'),
                  items: _fields
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(
                              f.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selected = v),
                ),
              ),
            ),
          ],
        ),
      ),

      // ✅ KEEP the same bottom nav bar design
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        currentIndex: 1,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "My farm"),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: "Store"),
          BottomNavigationBarItem(icon: Icon(Icons.article), label: "News"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Account"),
        ],
        onTap: (idx) {
          if (idx == 0) Navigator.pop(context); // Back to dashboard
        },
      ),

      body: selected == null
          ? const Center(child: Text("No saved fields"))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // MAP PREVIEW
                  SizedBox(
                    height: 220,
                    child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                        target: selected.points.first,
                        zoom: 17,
                  ),
                  mapType: MapType.satellite, // ✅ Makes the map satellite view
                  polygons: {
                    Polygon(
                      polygonId: const PolygonId('field'),
                      points: selected.points,
                      fillColor: Colors.green.withOpacity(0.3),
                      strokeColor: Colors.green,
                      strokeWidth: 2,
                    ),
                  },
                  markers: selected.points
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

                  // FIELD CARD
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.terrain, color: Colors.green, size: 30),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("${_calculateArea(selected.points).toStringAsFixed(2)} acre",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(selected.crop,
                                      style: const TextStyle(color: Colors.green, fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // FERTILISER PLAN CARD
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Fertiliser plan",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.grass, color: Colors.green, size: 40),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    "Know the right plan\nImprove your yield with a personalised fertiliser plan for your field.",
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lightBlue[50],
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text("Calculate"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // NUTRICHECK SECTION
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("NutriCheck",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 100,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _nutriCard("assets/nutri1.png"),
                              _nutriCard("assets/nutri2.png"),
                              _nutriCard("assets/nutri3.png"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _nutriCard(String asset) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(asset, width: 100, height: 100, fit: BoxFit.cover),
      ),
    );
  }
}
