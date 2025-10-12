import 'dart:io';
import 'dart:convert';
import 'package:http/io_client.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:my_app/config.dart';

class GeeAPI {
  static const String baseUrl = GEE_BASE;

  static final http.Client client = () {
    final ioc = HttpClient();
    ioc.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    return IOClient(ioc);
  }();

  static Future<Map<String, dynamic>> calculateCarbon(List<LatLng> polygon) async {
  final url = Uri.parse("$GEE_BASE/calculate_carbon");
    final body = {
      "coordinates": polygon.map((p) => {"lat": p.latitude, "lng": p.longitude}).toList()
    };

    final res = await client.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) throw Exception("Error: ${res.body}");
    return jsonDecode(res.body);
  }

  static Future<List<Map<String, dynamic>>> getTimeSeries(List<LatLng> polygon) async {
  final url = Uri.parse("$GEE_BASE/mrv/timeseries");
    final body = {
      "coordinates": polygon.map((p) => {"lat": p.latitude, "lng": p.longitude}).toList()
    };

    final res = await client.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) throw Exception("Error: ${res.body}");
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data["series"]);
  }
}
