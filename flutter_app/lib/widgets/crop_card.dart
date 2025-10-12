import 'package:flutter/material.dart';
import 'dart:io';

class CropCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String image;
  final VoidCallback? onTap;
  const CropCard({Key? key, required this.title, required this.subtitle, required this.image, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap ?? () => Navigator.of(context).pushNamed('/crop'),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: _isFile(image)
                  ? Image.file(File(image), fit: BoxFit.cover)
                  : Image.asset(image, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isFile(String path) {
  if (path.startsWith('http')) return false;
  // simple heuristic: absolute file path or file URI
  return path.startsWith('/') || path.startsWith('file://') || (Platform.isWindows && path.contains(':\\'));
}
