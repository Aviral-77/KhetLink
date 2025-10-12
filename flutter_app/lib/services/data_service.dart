import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/crop.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  static const _storageKey = 'crop_data_v1';

  final ValueNotifier<List<Crop>> crops = ValueNotifier<List<Crop>>([]);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        crops.value = list.map((e) => Crop.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        crops.value = _defaultCrops();
        await _save();
      }
    } else {
      crops.value = _defaultCrops();
      await _save();
    }
  }

  List<Crop> _defaultCrops() => [
        Crop(
          id: '1',
          image: 'assets/vegetables.jpg',
          title: 'Fresh Organic Tomatoes - 50kg',
          currentBid: 3500,
          quantity: '50kg',
          location: 'Punjab, India',
          postedDate: '5 Dec',
          seller: 'Ram Singh',
          description: 'Premium quality organic tomatoes, freshly harvested.',
          category: 'vegetables',
          featured: true,
          bids: [Bid(bidder: 'Raj Kumar', amount: 3600, time: '2 hours ago')],
        ),
        Crop(
          id: '2',
          image: 'assets/fruits.jpg',
          title: 'Premium Alphonso Mangoes - 100kg',
          currentBid: 12000,
          quantity: '100kg',
          location: 'Maharashtra, India',
          postedDate: '4 Dec',
          seller: 'Kamal Sharma',
          description: 'Sweet and juicy alphonso mangoes.',
          category: 'fruits',
        ),
        Crop(
          id: '3',
          image: 'assets/grains.jpg',
          title: 'Wheat Grain - 500kg',
          currentBid: 15000,
          quantity: '500kg',
          location: 'Haryana, India',
          postedDate: '3 Dec',
          seller: 'Sukhdev',
          description: 'High quality wheat grain.',
          category: 'grains',
        ),
      ];

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(crops.value.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  /// Clear all stored crop data and reset to defaults.
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    crops.value = _defaultCrops();
    await _save();
  }

  List<Crop> getAll() => List.unmodifiable(crops.value);

  Crop? getById(String id) {
    try {
      return crops.value.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addListing(Crop crop) async {
    crops.value = [...crops.value, crop];
    await _save();
  }

  Future<void> placeBid(String id, int amount, String bidder) async {
    final idx = crops.value.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final c = crops.value[idx];
    c.currentBid = amount;
    c.bids.insert(0, Bid(bidder: bidder, amount: amount, time: 'just now'));
    crops.value = [...crops.value];
    await _save();
  }

  Future<void> toggleFavorite(String id) async {
    // For simplicity we won't track favorites separately yet
  }
}
