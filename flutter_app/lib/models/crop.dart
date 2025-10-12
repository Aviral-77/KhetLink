class Bid {
  final String bidder;
  final int amount;
  final String time;

  Bid({required this.bidder, required this.amount, required this.time});
}

class Crop {
  final String id;
  final String title;
  final String image;
  int currentBid;
  final String quantity;
  final String location;
  final String postedDate;
  final String seller;
  final String description;
  final String category;
  final bool featured;
  final List<Bid> bids;

  Crop({
    required this.id,
    required this.title,
    required this.image,
    required this.currentBid,
    required this.quantity,
    required this.location,
    required this.postedDate,
    required this.seller,
    required this.description,
    required this.category,
    this.featured = false,
    List<Bid>? bids,
  }) : bids = bids ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'image': image,
        'currentBid': currentBid,
        'quantity': quantity,
        'location': location,
        'postedDate': postedDate,
        'seller': seller,
        'description': description,
        'category': category,
        'featured': featured,
        'bids': bids.map((b) => {'bidder': b.bidder, 'amount': b.amount, 'time': b.time}).toList(),
      };

  factory Crop.fromJson(Map<String, dynamic> j) => Crop(
        id: j['id'] as String,
        title: j['title'] as String,
        image: j['image'] as String,
        currentBid: (j['currentBid'] as num).toInt(),
        quantity: j['quantity'] as String,
        location: j['location'] as String,
        postedDate: j['postedDate'] as String,
        seller: j['seller'] as String,
        description: j['description'] as String,
        category: j['category'] as String,
        featured: j['featured'] as bool? ?? false,
        bids: (j['bids'] as List<dynamic>?)
                ?.map((e) => Bid(bidder: e['bidder'], amount: (e['amount'] as num).toInt(), time: e['time']))
                .toList() ??
            [],
      );
}
