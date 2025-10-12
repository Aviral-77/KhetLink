import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_app/services/farm_storage.dart';


class FarmMappingScreen extends StatefulWidget {
  final String fieldName;
  const FarmMappingScreen({super.key, required this.fieldName});

  @override
  State<FarmMappingScreen> createState() => _FarmMappingScreenState();
}

class _FarmMappingScreenState extends State<FarmMappingScreen> {
  final List<LatLng> _polygonPoints = [];
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // Set initial view (Noida) after controller is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(LatLng(28.5355, 77.3910), 15);
    });
  }

  double _calculateArea(List<LatLng> points) {
    if (points.length < 3) return 0.0;

    double area = 0.0;
    for (int i = 0; i < points.length; i++) {
      LatLng p1 = points[i];
      LatLng p2 = points[(i + 1) % points.length];
      area += (p1.longitude * p2.latitude) - (p2.longitude * p1.latitude);
    }
    return area.abs() / 2.0 * 111_139 * 111_139; // rough sqm conversion
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Mapping ${widget.fieldName}"), backgroundColor: Colors.green),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          // initial center/zoom set via MapController in initState
          onTap: (tapPosition, point) {
            setState(() {
              _polygonPoints.add(point);
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: const ['a', 'b', 'c'],
          ),
          if (_polygonPoints.isNotEmpty)
            PolygonLayer(polygons: [
              Polygon(
                points: _polygonPoints,
                color: Colors.green.withOpacity(0.3),
                borderColor: Colors.green,
                borderStrokeWidth: 2,
              )
            ]),
          MarkerLayer(
            markers: _polygonPoints
                .map<Marker>((point) => Marker(
                      point: point,
                      width: 30,
                      height: 30,
                      child: const Icon(Icons.location_on, color: Colors.red),
                    ))
                .toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.check),
        onPressed: () {
          double areaSqM = _calculateArea(_polygonPoints);
          double areaAcres = areaSqM / 4046.86;

          // After drawing, prompt for metadata and save the field
          _showSaveDialog(areaSqM, areaAcres);
        },
      ),
    );
  }

  Future<void> _showSaveDialog(double areaSqM, double areaAcres) async {
    final nameCtl = TextEditingController(text: widget.fieldName);
    String crop = 'Wheat';
    String location = 'Unknown';

    final res = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Save Field'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Field name')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: crop, items: ['Wheat','Rice','Maize','Barley'].map((c)=>DropdownMenuItem(value:c, child:Text(c))).toList(), onChanged: (v)=> crop = v ?? crop),
        const SizedBox(height: 8),
        Text('Area: ${areaAcres.toStringAsFixed(2)} acres'),
      ],),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(c, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          final id = DateTime.now().millisecondsSinceEpoch.toString();
          final field = {
            'id': id,
            'name': nameCtl.text,
            'location': location,
            'crop': crop,
            'timestamp': DateTime.now().toIso8601String(),
            'area_m2': areaSqM,
            'area_acres': areaAcres,
            'points': _polygonPoints.map((p)=>{'lat': p.latitude, 'lng': p.longitude}).toList()
          };
          await FarmStorage.saveField(field);
          Navigator.pop(c, true);
        }, child: const Text('Save')),
      ],
    ));

    if (res == true) {
      Navigator.pop(context, true);
    }
  }
}
