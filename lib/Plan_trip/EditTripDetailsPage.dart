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

  final List<String> baseQuestions = [
    "Give a name to your trip",
    "Where are you traveling to?",
    "What are your travel dates (start and end)?",
    "What’s your estimated budget for this trip?",
    "What type of trip is this? (e.g., leisure, adventure, cultural, relaxation)",
    "Are there any specific activities or experiences you're looking for?"
  ];

  final Map<String, List<String>> tripQuestions = {
    "family": [
      "Who are the family members joining you (ages if kids)?",
      "Would you like to include kid-friendly or family-oriented activities?",
      "Do you prefer family suites, vacation rentals, or adjoining hotel rooms?",
      "Do you need facilities like baby gear, high chairs, or strollers?"
    ],
    "solo": [
      "What’s the purpose of your solo trip (relaxation, exploration, personal growth)?",
      "Are there any specific safety concerns or travel precautions you'd like us to consider?",
      "Do you prefer social stays like hostels or private accommodations like hotels or Airbnbs?",
      "Would you like suggestions for solo-friendly tours or experiences?"
    ],
    "friends": [
      "How many friends are going on the trip?",
      "Do you want to include group-friendly activities like hikes, escape rooms, or parties?",
      "Are you looking for nightlife spots, beach clubs, or casual hangout places?",
      "Would you like to stay together in a shared space like a villa or split accommodations?"
    ],
    "business": [
      "What’s the primary business goal for this trip (conference, client meeting, networking)?",
      "Do you have a fixed schedule or time blocks we should work around?",
      "Do you need access to business amenities like meeting rooms, printing, or high-speed WiFi?",
      "Would you like help balancing work with leisure (e.g., after-work dining, local sightseeing)?"
    ]
  };

  final Map<String, List<String>> predefinedOptions = {
    "Do you prefer family suites, vacation rentals, or adjoining hotel rooms?": [
      "Family Suites", "Vacation Rentals", "Adjoining Rooms"
    ],
    "Do you need facilities like baby gear, high chairs, or strollers?": [
      "Yes", "No", "Maybe"
    ],
    "Do you prefer social stays like hostels or private accommodations like hotels or Airbnbs?": [
      "Hostels", "Hotels", "Airbnbs", "Other"
    ],
    "Would you like suggestions for solo-friendly tours or experiences?": [
      "Yes", "No", "Maybe"
    ],
    "Are you looking for nightlife spots, beach clubs, or casual hangout places?": [
      "Nightlife", "Beach Clubs", "Casual Hangouts", "All"
    ],
    "Would you like to stay together in a shared space like a villa or split accommodations?": [
      "Shared Villa", "Split Accommodations", "Don't Know"
    ],
    "Do you need access to business amenities like meeting rooms, printing, or high-speed WiFi?": [
      "Yes", "No", "Maybe"
    ],
    "Would you like help balancing work with leisure (e.g., after-work dining, local sightseeing)?": [
      "Yes", "No", "Not Sure"
    ],
    "What type of trip is this? (e.g., leisure, adventure, cultural, relaxation)": [
      "Leisure", "Adventure", "Cultural", "Relaxation", "Business", "Family", "Solo", "Friends"
    ],
  };

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

      List<String> allQuestions = [
        ...baseQuestions,
        ...(tripQuestions[tripType] ?? [])
      ];

      for (String question in allQuestions) {
        controllers[question] = TextEditingController(text: details?[question] ?? '');
      }

      // Separate controllers for travel dates
      controllers['startDate'] = TextEditingController(text: details?['startDate'] ?? '');
      controllers['endDate'] = TextEditingController(text: details?['endDate'] ?? '');

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

    List<String> questions = [
      ...baseQuestions,
      ...(tripQuestions[tripType] ?? [])
    ];

    return Scaffold(
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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: questions.map((question) {
                if (question == "What are your travel dates (start and end)?") {
                  return Column(
                    children: [
                      _buildDateField("Start Date", "startDate"),
                      SizedBox(height: 12),
                      _buildDateField("End Date", "endDate"),
                    ],
                  );
                } else if (predefinedOptions.containsKey(question)) {
                  return _buildDropdown(question, controllers[question]!, predefinedOptions[question]!);
                } else {
                  return _buildTextField(question, controllers[question]!);
                }
              }).toList(),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _saveEdits,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text("Save Changes", style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white.withOpacity(0.95),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, TextEditingController controller, List<String> options) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: DropdownButtonFormField<String>(
        value: controller.text.isEmpty ? options.first : controller.text,
        items: options.map((option) => DropdownMenuItem(value: option, child: Text(option))).toList(),
        onChanged: (value) {
          controller.text = value ?? '';
        },
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white.withOpacity(0.95),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildDateField(String label, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextField(
        controller: controllers[key],
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white.withOpacity(0.95),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onTap: () async {
          final pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (pickedDate != null) {
            controllers[key]?.text = pickedDate.toIso8601String().split('T')[0];
          }
        },
      ),
    );
  }
}
