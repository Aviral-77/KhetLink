import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/io_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_app/services/farm_storage.dart';
import 'package:my_app/services/api_service.dart';
import 'package:latlong2/latlong.dart' as ll;

class MapMyFarm extends StatefulWidget {
  const MapMyFarm({super.key});
  @override
  State<MapMyFarm> createState() => _MapMyFarmState();
}

class _MapMyFarmState extends State<MapMyFarm> {
  late GoogleMapController mapController;
  final LatLng _center = const LatLng(28.5355, 77.3910);

  final List<LatLng> _farmPoints = [];
  final Set<Marker> _markers = {};
  final Set<Polygon> _polygons = {};

  double _areaSqM = 0.0;
  double _carbonTons = 0.0;
  String _validationMessage = "";
  List<Map<String, dynamic>> _timeSeries = [];
  int? _lastRecordId;

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _addPoint(LatLng point) {
    setState(() {
      _farmPoints.add(point);
      final markerId = MarkerId('m${_farmPoints.length}');
      _markers.add(Marker(markerId: markerId, position: point));

      _polygons.clear();
      if (_farmPoints.length > 2) {
        _polygons.add(Polygon(
          polygonId: const PolygonId('farmPolygon'),
          points: _farmPoints,
          strokeWidth: 2,
          strokeColor: Colors.green,
          fillColor: Colors.green.withOpacity(0.25),
        ));
      }
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
    return area.abs() / 2 * 111139 * 111139; // rough in m²
  }

  void _resetFarm() {
    setState(() {
      _farmPoints.clear();
      _markers.clear();
      _polygons.clear();
      _areaSqM = 0;
      _carbonTons = 0;
      _timeSeries = [];
      _lastRecordId = null;
      _validationMessage = "";
    });
  }

  Future<void> _goToCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enable GPS')));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final pos =
        await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    mapController.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 18),
    ));
  }

  Future<void> _saveFieldFlow() async {
    if (_farmPoints.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add at least one point')));
      return;
    }

    final nameCtl = TextEditingController(text: 'My Field');
    final locCtl = TextEditingController(text: 'Unknown');
    final cropCtl = TextEditingController(text: 'Wheat');
    final areaStr = (_areaSqM / 10000).toStringAsFixed(2); // area in hectares

    final res = await showDialog<Map<String, String>>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Field Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Calculated Area: $areaStr ha'),
            const SizedBox(height: 12),
            TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Field name')),
            TextField(controller: locCtl, decoration: const InputDecoration(labelText: 'Field location')),
            TextField(controller: cropCtl, decoration: const InputDecoration(labelText: 'Crop')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, null), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, {
                    'name': nameCtl.text,
                    'location': locCtl.text,
                    'crop': cropCtl.text,
                  }),
              child: const Text('Save')),
        ],
      ),
    );

    if (res == null) return;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final field = {
      'id': id,
      'name': res['name'],
      'location': res['location'],
      'crop': res['crop'],
      'area_ha': double.parse(areaStr),
      'timestamp': DateTime.now().toIso8601String(),
      'points': _farmPoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
    };

    try {
      await FarmStorage.saveField(field);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Field saved')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _calculateCarbonCredits() async {
    if (_farmPoints.length < 3) {
      setState(() => _validationMessage = 'Draw at least 3 points.');
      return;
    }

    setState(() => _validationMessage = '');
    final coords = _farmPoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList();

    try {
      final data = await ApiService.calculateCarbon(coords);
      setState(() {
        _areaSqM = (data['area_m2'] ?? _calculateArea(_farmPoints)).toDouble();
        _carbonTons = (data['carbon_tons'] ?? 0.0).toDouble();
        _lastRecordId = data['record_id'];
      });

      await FarmStorage.savePolygon(
          _farmPoints.map((p) => ll.LatLng(p.latitude, p.longitude)).toList());

      final ts = await ApiService.fetchNdviSeries(coords);
      setState(() {
        _timeSeries = List<Map<String, dynamic>>.from(ts['series'] ?? []);
      });

      await _showCarbonDialog();
    } catch (e) {
      setState(() => _validationMessage = 'Network error: $e');
    }
  }

  Future<void> _showCarbonDialog() async {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Carbon Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Area: ${(_areaSqM / 10000).toStringAsFixed(3)} ha'),
            const SizedBox(height: 6),
            Text('Carbon: ${_carbonTons.toStringAsFixed(3)} tons'),
            const SizedBox(height: 6),
            Text('Carbon (kg): ${(_carbonTons * 1000).toStringAsFixed(1)} kg'),
            const SizedBox(height: 8),
            if (_timeSeries.isNotEmpty) const Text('NDVI series was fetched and is available.'),
            if (_timeSeries.isEmpty) const Text('No NDVI series available.'),
            if (_lastRecordId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Record ID: $_lastRecordId',
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
          TextButton(onPressed: () {
            Navigator.pop(c);
            _downloadReport();
          }, child: const Text('Generate PDF')),
          ElevatedButton(onPressed: () async {
            Navigator.pop(c);
            await _verifyCredits();
          }, child: const Text('Verify Credits')),
        ],
      ),
    );
  }

  Future<void> _verifyCredits() async {
    setState(() => _validationMessage = 'Verifying credits...');
    try {
      final recent = await ApiService.history(limit: 10);
      double avg = 0.0;
      int count = 0;
      for (final r in recent) {
        if (r is Map && r['carbon_tons'] != null) {
          avg += (r['carbon_tons'] as num).toDouble();
          count += 1;
        }
      }
      final avgCarbon = count > 0 ? avg / count : 0.0;
      String verdict;
      final delta = (_carbonTons - avgCarbon).abs();
      if (avgCarbon == 0 && _carbonTons > 0) {
        verdict = 'No baseline available – this is a new record.';
      } else if (delta / (avgCarbon == 0 ? 1 : avgCarbon) < 0.15) {
        verdict = 'Verification Passed – within expected range vs recent records.';
      } else if (delta / (avgCarbon == 0 ? 1 : avgCarbon) < 0.35) {
        verdict = 'Verification Warning – significant deviation from recent records.';
      } else {
        verdict = 'Verification Failed – large deviation from recent records.';
      }

      await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
                title: const Text('Verification Result'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Computed carbon: ${_carbonTons.toStringAsFixed(3)} tons'),
                    const SizedBox(height: 6),
                    Text('Recent average: ${avgCarbon.toStringAsFixed(3)} tons'),
                    const SizedBox(height: 8),
                    Text(verdict)
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))
                ],
              ));
    } catch (e) {
      setState(() => _validationMessage = 'Verification failed: $e');
      await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
                title: const Text('Verification Error'),
                content: Text('$e'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))
                ],
              ));
    } finally {
      setState(() => _validationMessage = '');
    }
  }

  Future<void> _downloadReport() async {
    if (_lastRecordId == null) {
      setState(() => _validationMessage = 'No saved record to download report for.');
      return;
    }

    final url = 'https://geoserver.bluehawk.ai:8045/gee/mrv/report/$_lastRecordId';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      setState(() => _validationMessage = 'Unable to open report URL.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map My Farm (MRV)'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _resetFarm),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(target: _center, zoom: 16),
            mapType: MapType.satellite,
            markers: _markers,
            polygons: _polygons,
            onTap: _addPoint,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: Container(
                margin: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_validationMessage.isNotEmpty)
                      Text(_validationMessage, style: const TextStyle(color: Colors.red)),

                    // Removed NDVI Time Series Card

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Farm Polygon Details', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Area: ${(_areaSqM / 10000).toStringAsFixed(2)} ha'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _saveFieldFlow,
                                  icon: const Icon(Icons.save),
                                  label: const Text('Save Field'),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: _resetFarm,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Refresh'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
