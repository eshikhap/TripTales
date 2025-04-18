import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'EditTripDetailsPage.dart';

class plantrip4 extends StatefulWidget {
  const plantrip4({super.key});

  @override
  _TripPlannerPageState createState() => _TripPlannerPageState();
}

class _TripPlannerPageState extends State<plantrip4> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? tripId;
  String? tripType;
  Map<String, TextEditingController> controllers = {};

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
    "What are your trip start and end dates?"
  ];

  @override
  void initState() {
    super.initState();
    _loadTripType();
  }

  Future<void> _loadTripType() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    tripId = prefs.getString('tripId');

    if (tripId != null) {
      DocumentSnapshot tripDoc = await FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .get();

      tripType = (tripDoc['tripType'] as String).toLowerCase();

      Map<String, dynamic>? existingAnswers =
          (tripDoc.data() as Map<String, dynamic>)['tripDetails'];

      for (String question in baseQuestions) {
        controllers[question] =
            TextEditingController(text: existingAnswers?[question] ?? '');
      }
      controllers['startDate'] =
          TextEditingController(text: existingAnswers?['startDate'] ?? '');
      controllers['endDate'] =
          TextEditingController(text: existingAnswers?['endDate'] ?? '');

      for (String question in tripQuestions[tripType] ?? []) {
        controllers[question] =
            TextEditingController(text: existingAnswers?[question] ?? '');
      }

      setState(() {});
    }
  }

  Future<void> _saveResponses() async {
    if (tripId == null || tripType == null) return;

    Map<String, dynamic> answers = {};
    controllers.forEach((key, controller) {
      answers[key] = controller.text;
    });

    await FirebaseFirestore.instance
        .collection('trips')
        .doc(tripId!)
        .update({'tripDetails': answers});
  }

  @override
  Widget build(BuildContext context) {
    if (tripType == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final questions = [
      ...baseQuestions,
      ...(tripQuestions[tripType] ?? [])
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF93A5CF), Color(0xFFE4EFE9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: const Text("Trip Planner", style: TextStyle(color: Colors.black)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.black),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => EditTripDetailsPage()),
                      );
                      _loadTripType();
                    },
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: questions.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final question = questions[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Question ${index + 1} of ${questions.length}",
                                style: TextStyle(color: Colors.black54),
                              ),
                              SizedBox(height: 30),
                              Text(
                                question,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 24),
                              if (question == "What are your trip start and end dates?")
                                Column(
                                  children: [
                                    _buildInputField("Start Date", controllers['startDate']),
                                    SizedBox(height: 12),
                                    _buildInputField("End Date", controllers['endDate']),
                                  ],
                                )
                              else
                                _buildInputField("Your Answer", controllers[question]),
                              SizedBox(height: 40),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (index > 0)
                                    _navButton("Back", Colors.grey.shade400, () {
                                      _pageController.previousPage(
                                          duration: Duration(milliseconds: 300),
                                          curve: Curves.easeInOut);
                                    }),
                                  if (index < questions.length - 1)
                                    _navButton("Next", Colors.blueAccent, () async {
                                      await _saveResponses();
                                      _pageController.nextPage(
                                          duration: Duration(milliseconds: 300),
                                          curve: Curves.easeInOut);
                                    }),
                                  if (index == questions.length - 1)
                                    _navButton("Finish", Colors.green, () async {
                                      await _saveResponses();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Trip details saved!")),
                                      );
                                    }),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController? controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.black87),
        filled: true,
        fillColor: Colors.white.withOpacity(0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.deepPurple),
        ),
      ),
    );
  }

  Widget _navButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Text(text, style: TextStyle(fontSize: 16)),
    );
  }
}
