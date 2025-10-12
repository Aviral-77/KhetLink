import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_app/config.dart';

class AIAnalysisCard extends StatefulWidget {
  const AIAnalysisCard({Key? key}) : super(key: key);

  @override
  State<AIAnalysisCard> createState() => _AIAnalysisCardState();
}

class _AIAnalysisCardState extends State<AIAnalysisCard> {
  File? _image;
  String? _s3Path;
  String? _selectedCrop;
  String? _imageId;
  String? _jobId;
  String? _jobStatus;
  Map<String, dynamic>? _jobResult;
  bool _uploading = false;
  bool _analyzing = false;
  Timer? _jobPoll;
  final Map<String, Uint8List?> _maskCache = {};

  final List<String> _cropTypes = ['wheat', 'rice', 'maize', 'barley', 'tomato'];

  // ---------------- Chat State ----------------
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _chatMessages = []; // {'role':'user'/'bot','msg':'...'}
  bool _sendingChat = false;

  // ---------------- Image Picker ----------------
  Future<void> _pickImage({required bool camera}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 900,
    );
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
        _s3Path = null;
        _imageId = null;
        _jobId = null;
        _jobStatus = null;
        _jobResult = null;
        _chatMessages.clear();
      });
    }
  }

  // ---------------- Upload (Simulated) ----------------
  Future<void> _uploadToS3() async {
    if (_image == null) return;
    setState(() => _uploading = true);

    try {
    const s3Url = S3_TEST_IMAGE;
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() => _s3Path = s3Url);

      await _showApiResponse(
        title: 'S3 Upload',
        body: {
          "method": "PUT (Simulated)",
          "endpoint": s3Url,
          "status": 200,
          "message": "Image successfully uploaded",
        },
      );
    } catch (e) {
      await _showApiResponse(
        title: "Upload Error",
        body: {"error": e.toString()},
      );
    } finally {
      setState(() => _uploading = false);
    }
  }

  // ---------------- Analysis ----------------
  Future<void> _startAnalysis() async {
    if (_s3Path == null || _selectedCrop == null) return;
    setState(() => _analyzing = true);

    try {
  final uploadUrl = Uri.parse(AI_UPLOAD_ENDPOINT);
      final uploadPayload = {
        "image_path": _s3Path,
        "farmer_id": "farmer_123",
        "crop": _selectedCrop
      };

      final resp1 = await http.post(
        uploadUrl,
        headers: {'content-type': 'application/json'},
        body: jsonEncode(uploadPayload),
      );

      if (resp1.statusCode != 200) {
        throw Exception("Upload API failed: ${resp1.statusCode}");
      }

      final obj1 = jsonDecode(resp1.body);
      _imageId = obj1['image_id'];

  final analyzeUrl = Uri.parse(AI_ANALYZE_ENDPOINT);
      final analyzePayload = {"image_id": _imageId, "crop": _selectedCrop};

      final resp2 = await http.post(
        analyzeUrl,
        headers: {'content-type': 'application/json'},
        body: jsonEncode(analyzePayload),
      );

      if (resp2.statusCode != 200) {
        throw Exception("Analyze API failed: ${resp2.statusCode}");
      }

      final obj2 = jsonDecode(resp2.body);
      setState(() {
        _jobId = obj2['job_id'];
        _jobStatus = obj2['status'];
      });

      _jobPoll?.cancel();
      _jobPoll = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _pollJobStatus(),
      );
    } catch (e) {
      await _showApiResponse(
          title: "Analysis Error", body: {"error": e.toString()});
    } finally {
      setState(() => _analyzing = false);
    }
  }

  // ---------------- Job Polling ----------------
  Future<void> _pollJobStatus() async {
    if (_jobId == null) return;
  final pollUrl = Uri.parse('$AI_POLL_ENDPOINT/$_jobId');

    try {
      final resp = await http.get(pollUrl);
      if (resp.statusCode != 200) throw Exception("Polling failed");

      final obj = jsonDecode(resp.body);
      setState(() => _jobStatus = obj['status']);

      if (obj['status'] == 'done') {
        _jobPoll?.cancel();
        setState(() => _jobResult = obj['results']);
      }
    } catch (e) {
      debugPrint("❌ Polling Error: $e");
      _jobPoll?.cancel();
    }
  }

  // ---------------- Download & Cache ----------------
  Future<String?> _downloadImage(String url) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      final streamed = await client.send(req).timeout(const Duration(seconds: 30));
      if (streamed.statusCode != 200) return null;

      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/mask_result_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      final sink = file.openWrite();
      await streamed.stream.pipe(sink);
      await sink.flush();
      await sink.close();
      return filePath;
    } catch (e) {
      debugPrint('❌ Download failed: $e');
      return null;
    } finally {
      client.close();
    }
  }

  Future<Uint8List?> _fetchMaskBytes(String url) async {
    try {
      if (_maskCache.containsKey(url)) return _maskCache[url];
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        _maskCache[url] = resp.bodyBytes;
        return resp.bodyBytes;
      }
      debugPrint('Mask fetch failed: ${resp.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Mask fetch error: $e');
      return null;
    }
  }

  // ---------------- Chat ----------------
  Future<void> _sendChat() async {
    if (_chatController.text.isEmpty || _jobResult == null || _imageId == null) return;
    final question = _chatController.text.trim();
    _chatController.clear();
    setState(() => _sendingChat = true);

    _chatMessages.add({'role': 'user', 'msg': question});

    final payload = {
      "farmer_id": "farmer_123",
      "image_id": _imageId,
      "question": question,
      "infected_area_pct": _jobResult?["infected_area_pct"] ?? 0,
      "severity": _jobResult?["severity"] ?? "unknown",
      "top_diseases": _jobResult?["top_diseases"] ?? [],
      "lang": "hi"
    };

    try {
      final resp = await http.post(
        Uri.parse(AI_CHAT_ENDPOINT),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (resp.statusCode == 200) {
        final obj = jsonDecode(resp.body);
        final answer = obj["answer"] ?? "No answer.";
        _chatMessages.add({'role': 'bot', 'msg': answer});
      } else {
        _chatMessages.add({'role': 'bot', 'msg': 'Error: ${resp.statusCode}'});
      }
    } catch (e) {
      _chatMessages.add({'role': 'bot', 'msg': 'Error: $e'});
    } finally {
      setState(() => _sendingChat = false);
    }
  }

  // ---------------- API Response Dialog ----------------
  Future<void> _showApiResponse({required String title, required dynamic body}) async {
    final pretty = const JsonEncoder.withIndent('  ').convert(body);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(pretty, style: const TextStyle(fontFamily: 'monospace')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _jobPoll?.cancel();
    _chatController.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("🌾 AI Crop Disease Analysis",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 20)),
              const SizedBox(height: 16),
              _buildImagePicker(),
              const SizedBox(height: 16),
              _buildCropDropdown(),
              const SizedBox(height: 16),
              _buildActionButton(),
              const SizedBox(height: 24),
              if (_jobId != null)
                _jobResult == null ? _buildStatusCard() : _buildResultCard(_jobResult!),
              if (_jobResult != null) _buildChatSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() => Row(
        children: [
          _image != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_image!, height: 70, width: 70, fit: BoxFit.cover),
                )
              : Container(
                  width: 70,
                  height: 70,
                  color: Colors.grey[200],
                  alignment: Alignment.center,
                  child: const Icon(Icons.image, color: Colors.grey)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.photo),
                        label: const Text("Gallery"),
                        onPressed: () => _pickImage(camera: false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text("Camera"),
                        onPressed: () => _pickImage(camera: true),
                      ),
                    ),
                  ],
                ),
                if (_image != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _uploading
                        ? const LinearProgressIndicator()
                        : OutlinedButton.icon(
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: Text(_s3Path == null ? "Upload to S3" : "Re-upload"),
                            onPressed: _s3Path == null ? _uploadToS3 : null,
                          ),
                  ),
              ],
            ),
          ),
        ],
      );

  Widget _buildCropDropdown() => DropdownButtonFormField<String>(
        value: _selectedCrop,
        items: _cropTypes
            .map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase())))
            .toList(),
        hint: const Text("Select Crop Type"),
        onChanged: (val) => setState(() => _selectedCrop = val!),
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );

  Widget _buildActionButton() => ElevatedButton.icon(
        icon: const Icon(Icons.analytics_outlined),
        label: _analyzing
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text("Start Analysis"),
        onPressed: _image == null || _s3Path == null || _selectedCrop == null || _analyzing
            ? null
            : _startAnalysis,
      );

  Widget _buildStatusCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Job ID: $_jobId", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text("Status: ${_jobStatus ?? 'processing...'}",
                style: GoogleFonts.poppins(
                    color: _jobStatus == "done" ? Colors.green : Colors.orangeAccent,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );

  Widget _buildResultCard(Map<String, dynamic> result) {
    final maskUrl = result["mask_url"];
    final severity = result["severity"] ?? "N/A";
    final infected = result["infected_area_pct"] ?? 0.0;
    final confidence = result["confidence"] ?? 0.0;
    final disease = result["top_diseases"]?[0]?["label"] ?? "Unknown";

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("🧠 AI Analysis Results",
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            const Divider(),
            Text("Disease: $disease"),
            Text("Severity: $severity"),
            Text("Infected Area: ${infected.toStringAsFixed(2)}%"),
            Text("Confidence: ${(confidence * 100).toStringAsFixed(1)}%"),
            const SizedBox(height: 10),
            if (maskUrl != null)
              FutureBuilder<Uint8List?>(
                future: _fetchMaskBytes(maskUrl),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                        height: 220, child: Center(child: CircularProgressIndicator()));
                  }
                  final bytes = snap.data;
                  if (bytes == null || bytes.isEmpty) {
                    return const SizedBox(
                      height: 220,
                      child: Center(
                        child: Icon(Icons.broken_image, size: 80, color: Colors.grey),
                      ),
                    );
                  }
                  return Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(bytes, fit: BoxFit.cover),
                    ),
                  );
                },
              ),
            if (maskUrl != null)
              TextButton.icon(
                onPressed: () async {
                  final path = await _downloadImage(maskUrl);
                  if (path != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Image saved at: $path")),
                    );
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text("Download Mask Image"),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatSection() => Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: ListView.builder(
                reverse: true,
                itemCount: _chatMessages.length,
                itemBuilder: (context, index) {
                  final msg = _chatMessages[_chatMessages.length - 1 - index];
                  final isUser = msg['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.green.shade200 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(msg['msg'] ?? ''),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: const InputDecoration(
                      hintText: "Ask about the disease...",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _sendingChat
                    ? const CircularProgressIndicator()
                    : IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _sendChat,
                      ),
              ],
            )
          ],
        ),
      );
}
