import 'dart:convert';
import 'dart:io';
import 'package:http/io_client.dart';
import 'dart:typed_data'; 
import 'package:my_app/config.dart';
class ApiService {
  static final IOClient client = () {
    final ioc = HttpClient();
    ioc.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true; // bypass SSL
    return IOClient(ioc);
  }();

  static Future<Map<String, dynamic>> fetchNdviSeries(List coords) async {
    final url = Uri.parse('$GEE_BASE/mrv/timeseries');
    final response = await client.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"coordinates": coords}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch NDVI data: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> calculateCarbon(List coords) async {
  final url = Uri.parse('$GEE_BASE/calculate_carbon');
    final response = await client.post(url, headers: {"Content-Type": "application/json"}, body: jsonEncode({"coordinates": coords}));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to calculate carbon: ${response.body}');
  }

  static Future<List<Map<String, dynamic>>> history({int limit = 20}) async {
  final url = Uri.parse('$GEE_BASE/mrv/history?limit=$limit');
    final resp = await client.get(url);
    if (resp.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
    throw Exception('Failed to fetch history: ${resp.body}');
  }

  static Future<Uint8List> fetchReport(int id) async {
    final url = Uri.parse(geeReportUrl(id));
    final resp = await client.get(url);
    if (resp.statusCode == 200) return resp.bodyBytes;
    throw Exception('Failed to fetch report: ${resp.body}');
  }
}
