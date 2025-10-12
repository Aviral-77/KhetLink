import 'package:flutter/material.dart';

class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Wajidpur field, Gautam Buddha Nagar",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            Text(
              "Wheat",
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date & update status
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("Thursday, 11 Sep",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text("Updated just now",
                      style: TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ),

            // Next 6 hours card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFFe0f2ff), Color(0xFFfefefe)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Next 6 hours",
                      style:
                          TextStyle(color: Colors.deepOrange, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text("32.9°",
                          style: TextStyle(
                              fontSize: 32, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Text("| 29.4°",
                          style: TextStyle(
                              fontSize: 20, color: Colors.black54)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text("Expect dry conditions for the next 6 hours."),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tabs (Today, Fri, Sat, Sun)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _DayTab(label: "Today, 11", isActive: true),
                  _DayTab(label: "Fri, 12"),
                  _DayTab(label: "Sat, 13"),
                  _DayTab(label: "Sun, 14"),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Advisory card with image
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                image: const DecorationImage(
                  image: AssetImage("assets/banner.jpg"), // Replace with farm image
                  fit: BoxFit.cover,
                  opacity: 0.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Spread and Spray advisory",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                      "Access advisory and hourly weather forecasts to choose the right time for your spread and spray."),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue),
                    child: const Text("Learn more"),
                  )
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Quick weather stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _WeatherStat(icon: Icons.cloud, label: "4% chance\n0mm Rain"),
                  _WeatherStat(icon: Icons.water_drop, label: "77%\nHumidity"),
                  _WeatherStat(
                      icon: Icons.thermostat, label: "Max 34°\nMin 26°"),
                  _WeatherStat(icon: Icons.air, label: "12 km/h\nWind"),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Hourly forecast header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text("Hourly Forecast",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Hourly forecast cards
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 8,
                itemBuilder: (context, i) {
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text("3 PM"),
                        SizedBox(height: 6),
                        Icon(Icons.wb_sunny),
                        SizedBox(height: 6),
                        Text("1%"),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _DayTab extends StatelessWidget {
  final String label;
  final bool isActive;
  const _DayTab({required this.label, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.orange.shade100 : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.orange : Colors.grey.shade300,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.orange : Colors.black,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _WeatherStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _WeatherStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(height: 6),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black)),
      ],
    );
  }
}
