import 'package:flutter/material.dart';
import '../services/data_service.dart'; // Update with your actual import paths
import '../models/crop.dart';           // Update with your actual import paths
import 'dart:io';

class MyAdsScreen extends StatelessWidget {
  const MyAdsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String currentUser = 'You'; // Replace with actual logged-in username if needed

    return Scaffold(
      appBar: AppBar(title: const Text('My Ads')),
      body: ValueListenableBuilder<List<Crop>>(
        valueListenable: DataService().crops,
        builder: (context, cropsList, _) {
          // Filter for crops listed by this user
          final myCrops = cropsList.where((crop) => crop.seller == currentUser).toList();

          if (myCrops.isEmpty) {
            return const Center(child: Text('No ads posted yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: myCrops.length,
            itemBuilder: (context, index) {
              final crop = myCrops[index];
              return MyAdTile(
                crop: crop,
                onApprove: (bid) {
                  showDialog(
                    context: context,
                    builder: (_) => SaleReceiptDialog(
                      crop: crop,
                      bid: bid,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// --- MyAdTile widget for each crop ---

class MyAdTile extends StatelessWidget {
  final Crop crop;
  final Function(Bid) onApprove;

  const MyAdTile({required this.crop, required this.onApprove, Key? key}) : super(key: key);

  Widget _cropImageWidget(String imagePath) {
    if (imagePath.startsWith('assets/')) {
      // Asset image
      return Image.asset(imagePath, height: 110, width: double.infinity, fit: BoxFit.cover);
    } else {
      // File image (check existence to avoid errors)
      final fileImage = File(imagePath);
      return fileImage.existsSync()
          ? Image.file(fileImage, height: 110, width: double.infinity, fit: BoxFit.cover)
          : Container(
              height: 110,
              width: double.infinity,
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, size: 30, color: Colors.grey)
            );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image/header/labels
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: _cropImageWidget(crop.image),
              ),
              if (crop.featured)
                Positioned(
                  left: 12, top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.yellow[700], borderRadius: BorderRadius.circular(6)),
                    child: const Text('FEATURED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))),
                ),
              Positioned(
                right: 12, top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.green, borderRadius: BorderRadius.circular(6)),
                  child: const Text('active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(crop.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 3),
                    Text('${crop.location}  •  ${crop.postedDate}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Current bid: ', style: TextStyle(fontSize: 12)),
                    Text('₹ ${crop.currentBid}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14)),
                    const SizedBox(width: 8),
                    Chip(label: Text(crop.quantity), backgroundColor: Colors.grey[100]),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Received Bids (${crop.bids.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (crop.bids.isEmpty) const Text('No bids received yet.', style: TextStyle(fontSize: 12)),
                ...crop.bids.map((bid) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bid.bidder, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Pending', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Text('₹ ${bid.amount}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(width: 5),
                      ElevatedButton(
                        onPressed: () => onApprove(bid),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text('Approve', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- SaleReceiptDialog widget for the popup ---

class SaleReceiptDialog extends StatelessWidget {
  final Crop crop;
  final Bid bid;

  const SaleReceiptDialog({required this.crop, required this.bid, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String txnId = 'TXN${DateTime.now().millisecondsSinceEpoch}'; // Example transaction id

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 50),
            const SizedBox(height: 8),
            const Text('Sale Approved!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            const Text('Transaction confirmed with buyer', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
                children: [
                  TableRow(children: [
                    const Text('Transaction ID', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text(txnId, textAlign: TextAlign.right),
                  ]),
                  TableRow(children: [
                    const Text('Crop'),
                    Text(crop.title, textAlign: TextAlign.right),
                  ]),
                  TableRow(children: [
                    const Text('Quantity'),
                    Text(crop.quantity, textAlign: TextAlign.right),
                  ]),
                  TableRow(children: [
                    const Text('Buyer'),
                    Text(bid.bidder, textAlign: TextAlign.right),
                  ]),
                  TableRow(children: [
                    const Text('Location'),
                    Text(crop.location, textAlign: TextAlign.right),
                  ]),
                  TableRow(children: [
                    const Text('Date'),
                    Text(DateTime.now().toIso8601String().substring(0, 10), textAlign: TextAlign.right),
                  ]),
                  TableRow(children: [
                    const Text('Amount Receivable'),
                    Text('₹ ${bid.amount}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sale approved! Please contact the buyer to arrange delivery details. Payment will be processed upon delivery.',
              style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download),
                    label: const Text('Download Receipt'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
