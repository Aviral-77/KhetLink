import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/services/data_service.dart';
import 'package:my_app/models/crop.dart' as model;
import 'package:uuid/uuid.dart';

class SellScreen extends StatefulWidget {
  const SellScreen({Key? key}) : super(key: key);

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _title, _category, _quantity, _price, _location, _description;
  List<XFile>? _images;
  final ImagePicker _picker = ImagePicker();

  final List<String> _categories = [
    'Fruits',
    'Grains',
    'Pulses',
    'Vegetables',
    'Herbs',
    'Flowers'
  ];

  Future<void> _selectImages() async {
    final images = await _picker.pickMultiImage();
    if (images != null && images.length <= 5) {
      setState(() => _images = images);
    } else if (images != null && images.length > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You can upload up to 5 photos only.')));
    }
  }

  Future<void> _captureImage() async {
    final photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _images = [...(_images ?? []), photo];
        if (_images!.length > 5) {
          // trim to 5
          _images = _images!.sublist(0, 5);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Max 5 photos.')));
        }
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // Build a Crop and save it via DataService
      final id = const Uuid().v4();
      final img = (_images != null && _images!.isNotEmpty) ? _images!.first.path : 'assets/vegetables.jpg';
      final crop = model.Crop(
        id: id,
        image: img,
        title: _title ?? 'Untitled',
        currentBid: int.tryParse(_price ?? '') ?? 0,
        quantity: _quantity ?? '',
        location: _location ?? '',
        postedDate: 'now',
        seller: 'You',
        description: _description ?? '',
        category: (_category ?? '').toLowerCase(),
      );

      DataService().addListing(crop).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Listing posted successfully!')));
        Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Listing'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Photos picker
              InkWell(
                onTap: _selectImages,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  height: 120,
                  width: double.infinity,
                  child: _images == null || _images!.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 40, color: Colors.green[700]),
                          const SizedBox(height: 8),
                          const Text('Add Photos'),
                          const SizedBox(height: 2),
                          const Text('Upload up to 5 photos', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _selectImages,
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Choose Files'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _captureImage,
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Capture'),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: _images!.map((img) => Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Image.file(
                            File(img.path), width: 60, height: 60, fit: BoxFit.cover,
                          ),
                        )).toList(),
                      ),
                ),
              ),
              const SizedBox(height: 14),
              // Crop Title
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Crop Title *',
                  hintText: 'e.g. Fresh Organic Tomatoes',
                ),
                onSaved: (v) => _title = v,
                validator: (v) => v == null || v.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),
              // Category dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Category *',
                ),
                items: _categories
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        ))
                    .toList(),
                onChanged: (v) => _category = v,
                validator: (v) => v == null || v.isEmpty ? 'Select a category' : null,
              ),
              const SizedBox(height: 12),
              // Quantity
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  hintText: 'e.g. 50kg, 100 units',
                ),
                onSaved: (v) => _quantity = v,
              ),
              const SizedBox(height: 12),
              // Bid price
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Starting Bid Price (₹) *',
                  hintText: 'e.g. 5000',
                ),
                keyboardType: TextInputType.number,
                onSaved: (v) => _price = v,
                validator: (v) => v == null || v.isEmpty ? 'Price required' : null,
              ),
              const SizedBox(height: 12),
              // Location
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g. Punjab, India',
                ),
                onSaved: (v) => _location = v,
              ),
              const SizedBox(height: 12),
              // Description
              TextFormField(
                minLines: 3,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe your crop, quality, harvest date, etc.',
                ),
                onSaved: (v) => _description = v,
              ),
              const SizedBox(height: 22),
              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Post Listing'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
