
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class UserInputPage extends StatefulWidget {
  const UserInputPage({super.key});

  @override
  _UserInputPageState createState() => _UserInputPageState();
}

class _UserInputPageState extends State<UserInputPage> {
  final TextEditingController _nameController = TextEditingController();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    Firebase.initializeApp(); // Ensure Firebase is initialized
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadFile(File file, String folder) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = FirebaseStorage.instance.ref().child('$folder/$fileName');

      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      print("✅ File uploaded successfully: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading file: $e');
      return null;
    }
  }

  Future<void> _saveToFirebase() async {
    String name = _nameController.text.trim();
    if (name.isEmpty || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please enter a name and select an image.")),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      String? imageUrl = await _uploadFile(_selectedImage!, "images");

      if (imageUrl != null) {
        await FirebaseFirestore.instance.collection("Image").add({
          "name": name,
          "url": imageUrl,
          
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Image uploaded successfully!")),
        );

        _nameController.clear();
        setState(() {
          _selectedImage = null;
          _isUploading = false;
        });
      } else {
        throw Exception("Image upload failed.");
      }
    } catch (e) {
      print("❌ Error saving to Firestore: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Upload failed: $e")),
      );
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Image to Firebase')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Enter Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _pickImage, child: const Text('Pick an Image')),
            if (_selectedImage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.file(_selectedImage!, height: 150, fit: BoxFit.cover),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isUploading ? null : _saveToFirebase,
              child: _isUploading
                  ? const CircularProgressIndicator()
                  : const Text('Upload to Firebase'),
            ),
          ],
        ),
      ),
    );
  }
}