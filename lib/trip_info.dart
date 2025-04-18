import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TripInfoPage extends StatefulWidget {
  final String tripId;

  const TripInfoPage({super.key, required this.tripId});

  @override
  State<TripInfoPage> createState() => _TripInfoPageState();
}

class _TripInfoPageState extends State<TripInfoPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool isEditing = false;
  Map<String, dynamic>? tripData;
  late TextEditingController titleController;
  late TextEditingController locationController;
  late TextEditingController descriptionController;
  List<String> hotels = [];
  List<String> places = [];
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    _loadTripInfo();
  }

  Future<void> _loadTripInfo() async {
    final doc = await _firestore.collection("trips").doc(widget.tripId).get();
    if (doc.exists) {
      final data = doc.data();
      setState(() {
        tripData = data;
        titleController = TextEditingController(text: data?['title'] ?? '');
        locationController = TextEditingController(text: data?['location'] ?? '');
        descriptionController = TextEditingController(text: data?['description'] ?? '');
        startDate = (data?['startDate'] as Timestamp?)?.toDate();
        endDate = (data?['endDate'] as Timestamp?)?.toDate();
        hotels = List<String>.from(data?['hotels'] ?? []);
        places = List<String>.from(data?['places'] ?? []);
      });
    }
  }

  bool get userIsMember {
    final currentUserId = _auth.currentUser?.uid;
    final members = List<String>.from(tripData?['members'] ?? []);
    return members.contains(currentUserId);
  }

  Future<void> _saveChanges() async {
    await _firestore.collection("trips").doc(widget.tripId).update({
      'title': titleController.text,
      'location': locationController.text,
      'description': descriptionController.text,
      'startDate': startDate,
      'endDate': endDate,
      'hotels': hotels,
      'places': places,
    });
    setState(() {
      isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Trip updated')));
  }

  @override
  Widget build(BuildContext context) {
    if (tripData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Info'),
        actions: [
          if (userIsMember && !isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => isEditing = true),
            ),
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildField("Title", titleController, isEditing),
            _buildField("Location", locationController, isEditing),
            _buildField("Description", descriptionController, isEditing, maxLines: 3),
            _buildDatePicker("Start Date", startDate, (newDate) => setState(() => startDate = newDate)),
            _buildDatePicker("End Date", endDate, (newDate) => setState(() => endDate = newDate)),
            const SizedBox(height: 20),
            Text("Members:", style: Theme.of(context).textTheme.titleMedium),
            ...List<String>.from(tripData?['members'] ?? []).map((uid) => Text("- $uid")),
            const SizedBox(height: 20),
            _buildListEditor("Hotels", hotels),
            _buildListEditor("Places to Visit", places),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, bool enabled, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? value, ValueChanged<DateTime> onPicked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListTile(
        title: Text("$label: ${value != null ? value.toLocal().toString().split(' ')[0] : 'Not set'}"),
        trailing: isEditing
            ? IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: value ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    onPicked(picked);
                  }
                },
              )
            : null,
      ),
    );
  }

  Widget _buildListEditor(String label, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...items.map((item) => ListTile(
              title: Text(item),
              trailing: isEditing
                  ? IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => setState(() => items.remove(item)),
                    )
                  : null,
            )),
        if (isEditing)
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Add new...',
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      setState(() => items.add(value));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.add, color: Colors.grey),
            ],
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}