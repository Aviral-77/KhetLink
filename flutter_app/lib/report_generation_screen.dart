import 'package:flutter/material.dart';

class ReportGenerationScreen extends StatelessWidget {
  const ReportGenerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Generate Reports"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: const Center(
        child: Text("Report Generation UI goes here",
            style: TextStyle(fontSize: 16)),
      ),
    );
  }
}
