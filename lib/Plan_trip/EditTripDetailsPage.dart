import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditTripDetailsPage extends StatefulWidget {
  @override
  _EditTripDetailsPageState createState() => _EditTripDetailsPageState();
}

class _EditTripDetailsPageState extends State<EditTripDetailsPage> {
  Map<String, TextEditingController> controllers = {};
  String? tripId;
  String? tripType;

  final Map<String, List<String>> tripQuestions = {
    "family": [
      "Who are the family members going?",
      "Do you need kid-friendly activities?",
      "Do you need family accommodation?",
    ],
    "solo": [
      "What’s your main goal for this solo trip?",
      "Do you have any safety concerns?",
      "Do you prefer hostels or hotels?",
    ],
    "friends": [
      "How many friends are joining?",
      "Do you want group activities?",
      "Do you prefer nightlife spots?",
    ],
    "business": [
      "What’s the main purpose of the trip?",
      "Any meetings scheduled?",
      "Do you need conference facilities?",
    ]
  };

  final List<String> baseQuestions = [
    "What is your destination?",
    "startDate",
    "endDate"
  ];

  @override
  void initState() {
    super.initState();
    _loadTripData();
  }

  Future<void> _loadTripData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    tripId = prefs.getString('tripId');

    if (tripId != null) {
      DocumentSnapshot tripDoc =
          await FirebaseFirestore.instance.collection('trips').doc(tripId!).get();
      tripType = (tripDoc['tripType'] as String).toLowerCase();

      Map<String, dynamic>? details =
          (tripDoc.data() as Map<String, dynamic>)['tripDetails'];

      for (var question in [...baseQuestions, ...(tripQuestions[tripType] ?? [])]) {
        controllers[question] = TextEditingController(text: details?[question] ?? '');
      }

      setState(() {});
    }
  }

  Future<void> _saveEdits() async {
    if (tripId == null) return;

    Map<String, dynamic> updatedAnswers = {};
    controllers.forEach((key, controller) {
      updatedAnswers[key] = controller.text;
    });

    await FirebaseFirestore.instance
        .collection('trips')
        .doc(tripId!)
        .update({'tripDetails': updatedAnswers});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Changes saved!")),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (controllers.isEmpty) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Edit Trip Details"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF93A5CF), Color(0xFFE4EFE9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: controllers.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 10),
                        TextField(
                          controller: entry.value,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _saveEdits,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.deepPurple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text("Save Changes", style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}
