import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/io_client.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/config.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_app/services/farm_storage.dart';
import 'package:my_app/api_service.dart';
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

  // MRV State
  double _areaSqM = 0.0;
  double _carbonTons = 0.0;
  String _validationMessage = "";
  List<Map<String, dynamic>> _timeSeries = [];
  int? _lastRecordId;

  // Pre-mapping details
  bool _detailsCollected = false;
  String _pendingFieldName = 'My Field';
  String _pendingCrop = 'Wheat';
  String _pendingLocation = 'Unknown';
  String _pendingPhone = '+999999071001';
  final List<String> _knownPhones = [
    '+999999071001',
    '+999999071002',
    '+999999071003',
    '+999999071004',
    '+999999071005',
  ];

  // helper to rebuild markers/polygon and area
  void _rebuildFromPoints() {
    _markers.clear();
    for (var i = 0; i < _farmPoints.length; i++) {
      final p = _farmPoints[i];
      _markers.add(Marker(markerId: MarkerId('m${i + 1}'), position: p));
    }
    _polygons.clear();
    if (_farmPoints.length > 2) {
      _polygons.add(Polygon(polygonId: const PolygonId('farmPolygon'), points: _farmPoints, strokeWidth: 2, strokeColor: Colors.green, fillColor: Colors.green.withOpacity(0.25)));
    }
    _areaSqM = _calculateArea(_farmPoints);
  }

  double _calculatePerimeterMeters(List<LatLng> points) {
    if (points.length < 2) return 0.0;
    final dist = ll.Distance();
    double sum = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      sum += dist.as(ll.LengthUnit.Meter, ll.LatLng(a.latitude, a.longitude), ll.LatLng(b.latitude, b.longitude));
    }
    return sum;
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  // ─────────────────────────────────────────────
  // Google Map setup
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  void initState() {
    super.initState();
    // Ask for pre-mapping details once the widget is shown
    WidgetsBinding.instance.addPostFrameCallback((_) => _collectPreMappingDetails());
  }

  Future<void> _collectPreMappingDetails() async {
    if (_detailsCollected) return;
    final nameCtl = TextEditingController(text: _pendingFieldName);
    String crop = _pendingCrop;
    String phoneSelection = _knownPhones.contains(_pendingPhone) ? _pendingPhone : 'custom';
    final customPhoneCtl = TextEditingController(text: _knownPhones.contains(_pendingPhone) ? '' : _pendingPhone);

    final res = await showDialog<bool>(
      context: context,
      // Use a StatefulBuilder so the dialog can rebuild when the dropdown changes
      builder: (c) => StatefulBuilder(builder: (c2, setStateDialog) => AlertDialog(
        title: const Text('Field details'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Field name')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: crop,
            items: ['Wheat','Rice','Maize','Barley']
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) => crop = v ?? crop,
          ),
          const SizedBox(height: 8),
          // Phone selection: preset list + custom
          DropdownButtonFormField<String>(
            value: phoneSelection,
            items: [
              ..._knownPhones.map((p) => DropdownMenuItem(value: p, child: Text(p))),
              const DropdownMenuItem(value: 'custom', child: Text('Custom number...')),
            ],
            onChanged: (v) {
              setStateDialog(() {
                phoneSelection = v ?? 'custom';
              });
            },
            decoration: const InputDecoration(labelText: 'Phone for network lookup'),
          ),
          if (phoneSelection == 'custom') ...[
            const SizedBox(height: 8),
            TextField(controller: customPhoneCtl, decoration: const InputDecoration(labelText: 'Enter phone number (E.164)')),
          ]
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Start Mapping')),
        ],
      )),
    );

    if (res == true) {
      // decide phone
      final selectedPhone = phoneSelection == 'custom' ? customPhoneCtl.text.trim() : phoneSelection;
      setState(() {
        _pendingFieldName = nameCtl.text;
        _pendingCrop = crop;
        _pendingPhone = (selectedPhone?.isNotEmpty ?? false) ? selectedPhone : _pendingPhone;
        _detailsCollected = true;
      });
    } else {
      // if cancelled, pop this screen
      Navigator.pop(context);
    }
  }

  void _undoLastPoint() {
    if (_farmPoints.isEmpty) return;
    setState(() {
      _farmPoints.removeLast();
      _rebuildFromPoints();
    });
  }

  void _addPoint(LatLng point) {
    setState(() {
      _farmPoints.add(point);
      _rebuildFromPoints();
    });
  }

  // ─────────────────────────────────────────────
  // Area calculation
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

  // ─────────────────────────────────────────────
  // GPS and field saving
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

  // Retrieve approximate location using Nokia Network-as-Code (RapidAPI)
  // Note: You must provide your RapidAPI key below.
  static final String _nokiaRapidApiKey = RAPIDAPI_KEY;
  static const String _nokiaRapidApiHost = NETWORK_AS_CODE_HOST;

  Future<void> _jumpToNetworkLocationFlow() async {
    // use pending phone by default, allow override
    final phoneCtl = TextEditingController(text: _pendingPhone);
    final res = await showDialog<String?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Retrieve location (Nokia Network-as-Code)'),
        content: TextField(
          controller: phoneCtl,
          decoration: const InputDecoration(labelText: 'Phone number (E.164)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, null), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, phoneCtl.text.trim()), child: const Text('Locate')),
        ],
      ),
    );

    if (res == null || res.isEmpty) return;
    final latlng = await _getNetworkLatLng(res);
    if (latlng == null) return;
    mapController.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: latlng, zoom: 18)));
    setState(() { _markers.add(Marker(markerId: const MarkerId('network_loc'), position: latlng)); });
  }

  Future<void> _retrieveNetworkLocation(String phoneNumber) async {
      if (_nokiaRapidApiKey == 'REPLACE_WITH_RAPIDAPI_KEY') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Set your RapidAPI key via environment variable to use Nokia Network-as-Code')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Requesting location...')));

    try {
  final url = Uri.parse(NETWORK_AS_CODE_URL);
      final payload = jsonEncode({'device': {'phoneNumber': phoneNumber}, 'maxAge': 60});
      final resp = await http.post(url, headers: {
        'Content-Type': 'application/json',
        'x-rapidapi-host': _nokiaRapidApiHost,
        'x-rapidapi-key': _nokiaRapidApiKey,
      }, body: payload).timeout(const Duration(seconds: 20));

      if (resp.statusCode != 200) throw Exception('Status ${resp.statusCode}: ${resp.body}');

      final obj = jsonDecode(resp.body);
      final llg = _extractLatLng(obj);
      if (llg == null) throw Exception('No latitude/longitude found in response');

      // animate map and add marker
      mapController.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(llg.latitude, llg.longitude), zoom: 18)));
      setState(() {
        _markers.add(Marker(markerId: const MarkerId('network_loc'), position: LatLng(llg.latitude, llg.longitude)));
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Moved to network-derived location')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to retrieve location: $e')));
    }
  }

  // Helper used by flows to get LatLng or null with proper error handling
  Future<LatLng?> _getNetworkLatLng(String phoneNumber) async {
    try {
  final url = Uri.parse(NETWORK_AS_CODE_URL);
      final payload = jsonEncode({'device': {'phoneNumber': phoneNumber}, 'maxAge': 60});
      final resp = await http.post(url, headers: {
        'Content-Type': 'application/json',
        'x-rapidapi-host': _nokiaRapidApiHost,
        'x-rapidapi-key': _nokiaRapidApiKey,
      }, body: payload).timeout(const Duration(seconds: 20));

      if (resp.statusCode != 200) {
        debugPrint('Network location API failed: ${resp.statusCode} ${resp.body}');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network lookup failed')));
        return null;
      }
      final obj = jsonDecode(resp.body);
      final llg = _extractLatLng(obj);
      if (llg == null) {
        debugPrint('No lat/lng found in response: $obj');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No coordinates in API response')));
      }
      return llg;
    } catch (e) {
      debugPrint('Error fetching network latlng: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error retrieving network location: $e')));
      return null;
    }
  }

  // Recursively search a JSON-like object for a lat/lon pair.
  LatLng? _extractLatLng(dynamic obj) {
    if (obj == null) return null;
    if (obj is Map) {
      // common key names
      final keys = obj.keys.map((k) => k.toString().toLowerCase()).toList();
      if ((keys.contains('latitude') || keys.contains('lat')) && (keys.contains('longitude') || keys.contains('lon') || keys.contains('lng'))) {
        final lat = obj['latitude'] ?? obj['lat'];
        final lon = obj['longitude'] ?? obj['lon'] ?? obj['lng'];
        if (lat is num && lon is num) return LatLng(lat.toDouble(), lon.toDouble());
      }
      // nested common pattern: location: {position: {latitude, longitude}}
      if (obj.containsKey('location')) {
        final r = _extractLatLng(obj['location']);
        if (r != null) return r;
      }
      for (final v in obj.values) {
        final r = _extractLatLng(v);
        if (r != null) return r;
      }
    } else if (obj is List) {
      for (final v in obj) {
        final r = _extractLatLng(v);
        if (r != null) return r;
      }
    }
    return null;
  }

  Future<void> _saveFieldFlow() async {
    if (_farmPoints.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add at least one point')));
      return;
    }

    final nameCtl = TextEditingController(text: 'My Field');
    String crop = 'Wheat';
    String location = 'Fetching...';

    // compute area now
    final areaSqM = _calculateArea(_farmPoints);
    final areaHa = areaSqM / 10000.0;

    // Attempt to fetch location using pending phone number
    try {
      final latlng = await _getNetworkLatLng(_pendingPhone);
      if (latlng != null) {
        location = '${latlng.latitude.toStringAsFixed(5)}, ${latlng.longitude.toStringAsFixed(5)}';
      } else {
        location = 'Unknown';
      }
    } catch (e) {
      location = 'Unknown';
    }

    final res = await showDialog<Map<String, String>>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Save Field'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Field name')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: crop,
              items: ['Wheat', 'Rice', 'Maize', 'Barley']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => crop = v ?? crop,
              decoration: const InputDecoration(labelText: 'Crop type'),
            ),
            const SizedBox(height: 8),
            Text('Calculated area: ${areaHa.toStringAsFixed(3)} ha'),
            const SizedBox(height: 8),
            Text('Location: $location'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, null), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, {'name': nameCtl.text, 'location': location, 'crop': crop}),
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
      'phone': _pendingPhone,
      'crop': res['crop'],
      'timestamp': DateTime.now().toIso8601String(),
      'points': _farmPoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
    };

    try {
      // include area in saved field
      field['area_m2'] = areaSqM;
      field['area_ha'] = areaSqM / 10000.0;
      await FarmStorage.saveField(field);
      // show popup/snackbar to indicate added and then return
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Field added')));
      // consider resetting the map for a fresh drawing
      _resetFarm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  // ─────────────────────────────────────────────
  // Carbon & NDVI computation
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

      // Save polygon locally
      await FarmStorage.savePolygon(
          _farmPoints.map((p) => ll.LatLng(p.latitude, p.longitude)).toList());

      // Fetch NDVI time series
      final ts = await ApiService.fetchNdviSeries(coords);
      setState(() {
        _timeSeries = List<Map<String, dynamic>>.from(ts['series'] ?? []);
      });

      // show carbon summary + actions
      await _showCarbonDialog();
    } catch (e) {
      setState(() => _validationMessage = 'Network error: $e');
    }
  }

  Future<void> _showCarbonDialog() async {
    // Present a dialog with carbon metrics and actions
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
            if (_lastRecordId != null) Padding(padding: const EdgeInsets.only(top:8.0), child: Text('Record ID: $_lastRecordId', style: const TextStyle(fontSize: 12, color: Colors.black54))),
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
      // compute average carbon_tons from recent records (if available)
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
        verdict = 'No baseline available — this is a new record.';
      } else if (delta / (avgCarbon == 0 ? 1 : avgCarbon) < 0.15) {
        verdict = 'Verification Passed — within expected range vs recent records.';
      } else if (delta / (avgCarbon == 0 ? 1 : avgCarbon) < 0.35) {
        verdict = 'Verification Warning — significant deviation from recent records.';
      } else {
        verdict = 'Verification Failed — large deviation from recent records.';
      }

      await showDialog<void>(context: context, builder: (c) => AlertDialog(title: const Text('Verification Result'), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Computed carbon: ${_carbonTons.toStringAsFixed(3)} tons'), const SizedBox(height: 6), Text('Recent average: ${avgCarbon.toStringAsFixed(3)} tons'), const SizedBox(height: 8), Text(verdict)]), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))]));
    } catch (e) {
      setState(() => _validationMessage = 'Verification failed: $e');
      await showDialog<void>(context: context, builder: (c) => AlertDialog(title: const Text('Verification Error'), content: Text('$e'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))]));
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

  // ─────────────────────────────────────────────
  // Chart widgets and info metrics
  Widget _buildTimeSeriesChart() {
    if (_timeSeries.isEmpty) {
      return const Text('No time-series available. Press the leaf button to compute.');
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < _timeSeries.length; i++) {
      final v = (_timeSeries[i]['ndvi'] ?? _timeSeries[i]['value'] ?? 0.0).toDouble();
      spots.add(FlSpot(i.toDouble(), v));
    }

    return SizedBox(
      height: 140,
      child: LineChart(LineChartData(
        minY: 0,
        maxY: 1,
        lineBarsData: [
          LineChartBarData(spots: spots, isCurved: true, barWidth: 2),
        ],
        titlesData: FlTitlesData(show: false),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
      )),
    );
  }

  String _currentNdviString() {
    if (_timeSeries.isEmpty) return '—';
    final last = _timeSeries.last;
    final v = (last['ndvi'] ?? last['value'] ?? 0.0).toDouble();
    return v.toStringAsFixed(2);
  }

  String _accuracyString() {
    final n = _timeSeries.length;
    final score = (50 + (n * 5)).clamp(50, 99);
    return '${score.toStringAsFixed(1)}%';
  }

  // ─────────────────────────────────────────────
  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map My Farm (MRV)'),
        backgroundColor: Colors.green,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _resetFarm)],
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(target: _center, zoom: 16),
            mapType: MapType.satellite,
            markers: _markers,
            polygons: _polygons,
            onTap: (pos) {
              if (!_detailsCollected) return; // require pre-mapping details
              _addPoint(pos);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),

          // Top summary card
          if (_farmPoints.length >= 3)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Perimeter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(_formatDistance(_calculatePerimeterMeters(_farmPoints)), style: const TextStyle(color: Colors.white)),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('Area (ha)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${(_areaSqM / 10000).toStringAsFixed(3)}', style: const TextStyle(color: Colors.white)),
                    ])
                  ],
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _saveFieldFlow,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Boundary'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                    ElevatedButton.icon(
                      onPressed: _farmPoints.isNotEmpty ? _undoLastPoint : null,
                      icon: const Icon(Icons.undo),
                      label: const Text('Undo'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'gps',
            onPressed: _goToCurrentLocation,
            backgroundColor: Colors.green,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'network_loc',
            onPressed: _jumpToNetworkLocationFlow,
            backgroundColor: Colors.blueGrey,
            child: const Icon(Icons.network_check),
          ),
        ],
      ),
    );
  }
}
