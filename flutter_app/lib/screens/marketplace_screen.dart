import 'package:flutter/material.dart';
import 'package:my_app/screens/listings_screen.dart';
import 'package:my_app/screens/sell_screen.dart';
import 'package:my_app/screens/my_ads_screen.dart';
import '../widgets/category_card.dart';
import '../widgets/crop_card.dart';
import '../services/data_service.dart';
import '../models/crop.dart' as model;
import '../services/farm_storage.dart';
import '../widgets/app_header.dart';

/// Clean marketplace home screen. One class only to avoid duplicate-symbol problems.
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  static const List<Map<String, String>> categories = [
    {'title': 'Vegetables', 'image': 'assets/vegetables.jpg'},
    {'title': 'Fruits', 'image': 'assets/fruits.jpg'},
    {'title': 'Grains', 'image': 'assets/grains.jpg'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Scaffold(
        appBar: AppHeader(
          title: "KhetLink MarketPlace",
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'clear') {
                  final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Clear data'), content: const Text('Remove all stored app data? This cannot be undone.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clear'))]));
                  if (ok == true) {
                    await FarmStorage.clearAll();
                    await DataService().clearAllData();
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Local data cleared')));
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'clear', child: Text('Clear local data')),
              ],
            )
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewPadding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_box_outlined),
                        label: const Text('Sell your Crop'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SellScreen())),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.announcement),
                        label: const Text('View Ads'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyAdsScreen())),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),

              GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: categories
                    .map((c) => CategoryCard(
                          title: c['title']!,
                          icon: Icons.grass,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListingsScreen(category: c['title']!.toLowerCase()))),
                        ))
                    .toList(),
              ),

              const SizedBox(height: 16),
              const Text('Recently viewed', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              ValueListenableBuilder<List<model.Crop>>(
                valueListenable: DataService().crops,
                builder: (context, list, _) {
                  return Column(
                    children: list
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: CropCard(
                                title: c.title,
                                subtitle: '\u20B9 ${c.currentBid} • ${c.location}',
                                image: c.image,
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CropDetailScreen(id: c.id))),
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
              // Extra spacer to avoid tiny bottom overflow on some devices
              SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 24),
            ],
          ),
        ),
      ),
    );
  }
}


