import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class TripFormScreen extends StatefulWidget {
  const TripFormScreen({super.key});

  @override
  _TripFormScreenState createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _collaboratorsController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];
  final List<File> _selectedVideos = [];
  bool _isUploading = false;

  /// Function to Pick Images
  Future<void> _pickImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    setState(() {
      _selectedImages = pickedFiles.map((file) => File(file.path)).toList();
    });
    }

  /// Function to Pick Videos
  Future<void> _pickVideos() async {
    final XFile? pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedVideos.add(File(pickedFile.path));
      });
    }
  }

  /// Upload Media to Firebase Storage and Get URLs
  Future<List<String>> _uploadFiles(List<File> files, String folder) async {
    List<String> urls = [];
    for (File file in files) {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      Reference ref = FirebaseStorage.instance.ref().child('$folder/$fileName');
      await ref.putFile(file);
      String downloadUrl = await ref.getDownloadURL();
      urls.add(downloadUrl);
    }
    return urls;
  }

  /// Save Trip Data to Firestore
  Future<void> _saveTrip() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUploading = true;
      });

      try {
        // Upload images and videos to Firebase Storage
        List<String> imageUrls = await _uploadFiles(_selectedImages, "trip_images");
        List<String> videoUrls = await _uploadFiles(_selectedVideos, "trip_videos");

        // Save trip data in Firestore
        await FirebaseFirestore.instance.collection('trips').add({
          'destination': _destinationController.text,
          'startDate': _startDateController.text,
          'endDate': _endDateController.text,
          'category': _categoryController.text,
          'collaborators': _collaboratorsController.text.split(',').map((e) => e.trim()).toList(),
          'images': imageUrls,
          'videos': videoUrls,
          'dayWiseDetails': [],
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Show success message and reset form
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Trip saved successfully!')));
        _formKey.currentState!.reset();
        setState(() {
          _selectedImages.clear();
          _selectedVideos.clear();
          _isUploading = false;
        });
      } catch (e) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Trip')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _destinationController,
                  decoration: InputDecoration(labelText: 'Destination'),
                  validator: (value) => value!.isEmpty ? 'Enter a destination' : null,
                ),
                TextFormField(
                  controller: _startDateController,
                  decoration: InputDecoration(labelText: 'Start Date (YYYY-MM-DD)'),
                  validator: (value) => value!.isEmpty ? 'Enter start date' : null,
                ),
                TextFormField(
                  controller: _endDateController,
                  decoration: InputDecoration(labelText: 'End Date (YYYY-MM-DD)'),
                  validator: (value) => value!.isEmpty ? 'Enter end date' : null,
                ),
                TextFormField(
                  controller: _categoryController,
                  decoration: InputDecoration(labelText: 'Category (e.g., Business, Family)'),
                  validator: (value) => value!.isEmpty ? 'Enter category' : null,
                ),
                TextFormField(
                  controller: _collaboratorsController,
                  decoration: InputDecoration(labelText: 'Collaborators (comma-separated)'),
                ),
                const SizedBox(height: 10),

                /// Image Picker
                ElevatedButton.icon(
                  onPressed: _pickImages,
                  icon: Icon(Icons.image),
                  label: Text('Pick Images'),
                ),
                Wrap(
                  children: _selectedImages
                      .map((img) => Padding(
                            padding: const EdgeInsets.all(5.0),
                            child: Image.file(img, width: 80, height: 80, fit: BoxFit.cover),
                          ))
                      .toList(),
                ),

                /// Video Picker
                ElevatedButton.icon(
                  onPressed: _pickVideos,
                  icon: Icon(Icons.video_collection),
                  label: Text('Pick Videos'),
                ),
                Wrap(
                  children: _selectedVideos
                      .map((vid) => Padding(
                            padding: const EdgeInsets.all(5.0),
                            child: Icon(Icons.video_file, size: 50, color: Colors.redAccent),
                          ))
                      .toList(),
                ),

                const SizedBox(height: 20),

                /// Upload Button
                _isUploading
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _saveTrip,
                        child: Text('Save Trip'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
