import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_app/services/data_service.dart';
import 'package:my_app/models/crop.dart' as model;
import '../widgets/crop_card.dart';

class ListingsScreen extends StatelessWidget {
  final String? category;
  const ListingsScreen({Key? key, this.category}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category == null ? 'Listings' : category!.toUpperCase())),
      body: ValueListenableBuilder<List<model.Crop>>(
        valueListenable: DataService().crops,
        builder: (context, list, _) {
          final items = category == null ? list : list.where((c) => c.category == category).toList();
          if (items.isEmpty) return const Center(child: Text('No listings yet'));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, idx) {
              final c = items[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CropCard(
                  title: c.title,
                  subtitle: '\u20B9 ${c.currentBid} • ${c.location} • ${c.quantity}',
                  image: c.image,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CropDetailScreen(id: c.id))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CropDetailScreen extends StatelessWidget {
  final String id;
  const CropDetailScreen({Key? key, required this.id}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<model.Crop>>(
      valueListenable: DataService().crops,
      builder: (context, list, _) {
        model.Crop? crop;
        try {
          crop = list.firstWhere((c) => c.id == id);
        } catch (_) {
          crop = null;
        }
        if (crop == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Not found')));

  final TextEditingController bidController = TextEditingController();
  final c = crop!;
  final minHint = '\u20B9 ${c.currentBid + 1}';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Crop Detail'),
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border)),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // header image
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: crop.image.startsWith('/') || crop.image.startsWith('file://') || crop.image.startsWith('http')
                      ? Image.file(File(crop.image), fit: BoxFit.cover)
                      : Image.asset(crop.image, fit: BoxFit.cover),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // title and meta
                    Text(c.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Text('\u20B9 ${c.currentBid}', style: TextStyle(color: Colors.green[700], fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.grey.shade200),
                        child: Text(c.quantity, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ]),

                    const SizedBox(height: 12),
                    Text(c.description),

                    const SizedBox(height: 12),
                    // info box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Location: ${c.location}'),
                        const SizedBox(height: 6),
                        Text('Posted: ${c.postedDate}'),
                        const SizedBox(height: 6),
                        Text('Seller: ${c.seller}'),
                      ]),
                    ),

                    const SizedBox(height: 18),
                    const Text('Recent Bids', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (c.bids.isEmpty)
                      const Text('No bids yet')
                    else
                      Column(
                        children: c.bids.map((b) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(b.bidder),
                            subtitle: Text(b.time),
                            trailing: Text('\u20B9 ${b.amount}'),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: bidController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(hintText: 'Enter bid ( > $minHint )'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        onPressed: () async {
                          final v = int.tryParse(bidController.text);
                          if (v == null || v <= c.currentBid) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a bid higher than current')));
                            return;
                          }
                          await DataService().placeBid(c.id, v, 'You');
                          bidController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bid placed')));
                        },
                        child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12), child: Text('Place Bid')),
                      ),
                    ])
                  ]),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
