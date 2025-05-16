import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'EditTripDetailsPage.dart';
import 'Interest.dart';

class plantrip4 extends StatefulWidget {
  @override
  _TripPlannerPageState createState() => _TripPlannerPageState();
}

class _TripPlannerPageState extends State<plantrip4> {
  PageController _pageController = PageController();
  int _currentPage = 0;
  String? tripId;
  String? tripType;
  String? trip;
  Map<String, TextEditingController> controllers = {};

  final Map<String, List<String>> tripQuestions = {
    "family": [
      "Who are the family members joining you (ages if kids)?",
      "Would you like to include kid-friendly or family-oriented activities?",
      "Do you prefer family suites, vacation rentals, or adjoining hotel rooms?",
      "Do you need facilities like baby gear, high chairs, or strollers?",
    ],
    "solo": [
      "What’s the purpose of your solo trip (relaxation, exploration, personal growth)?",
      "Are there any specific safety concerns or travel precautions you'd like us to consider?",
      "Do you prefer social stays like hostels or private accommodations like hotels or Airbnbs?",
      "Would you like suggestions for solo-friendly tours or experiences?",
    ],
    "friends": [
      "How many friends are going on the trip?",
      "Do you want to include group-friendly activities like hikes, escape rooms, or parties?",
      "Are you looking for nightlife spots, beach clubs, or casual hangout places?",
      "Would you like to stay together in a shared space like a villa or split accommodations?",
    ],
    "business": [
      "What’s the primary business goal for this trip (conference, client meeting, networking)?",
      "Do you have a fixed schedule or time blocks we should work around?",
      "Do you need access to business amenities like meeting rooms, printing, or high-speed WiFi?",
      "Would you like help balancing work with leisure (e.g., after-work dining, local sightseeing)?",
    ],
  };

  final List<String> baseQuestions = [
    "Give a name to your trip",
    "Where are you traveling to?",
    "What are your travel dates (start and end)?",
    "What’s your estimated budget for this trip?",
    "What type of trip is this? (e.g., leisure, adventure, cultural, relaxation)",
    "Are there any specific activities or experiences you're looking for?",
  ];

  final Map<String, List<String>> predefinedOptions = {
    "Do you prefer family suites, vacation rentals, or adjoining hotel rooms?":
        ["Family Suites", "Vacation Rentals", "Adjoining Rooms"],
    "Do you need facilities like baby gear, high chairs, or strollers?": [
      "Yes",
      "No",
      "Maybe",
    ],
    "Do you prefer social stays like hostels or private accommodations like hotels or Airbnbs?":
        ["Hostels", "Hotels", "Airbnbs", "Other"],
    "Would you like suggestions for solo-friendly tours or experiences?": [
      "Yes",
      "No",
      "Maybe",
    ],
    "Are you looking for nightlife spots, beach clubs, or casual hangout places?":
        ["Nightlife", "Beach Clubs", "Casual Hangouts", "All"],
    "Would you like to stay together in a shared space like a villa or split accommodations?":
        ["Shared Villa", "Split Accommodations", "Don't Know"],
    "Do you need access to business amenities like meeting rooms, printing, or high-speed WiFi?":
        ["Yes", "No", "Maybe"],
    "Would you like help balancing work with leisure (e.g., after-work dining, local sightseeing)?":
        ["Yes", "No", "Not Sure"],
    "What type of trip is this? (e.g., leisure, adventure, cultural, relaxation)":
        [
          "Leisure",
          "Adventure",
          "Cultural",
          "Relaxation",
          "Business",
          "Family",
          "Solo",
          "Friends",
        ],
  };

  @override
  void initState() {
    super.initState();
    _loadTripType();
  }

  Future<void> _loadTripType() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    tripId = prefs.getString('tripId');

    if (tripId != null) {
      DocumentSnapshot tripDoc =
          await FirebaseFirestore.instance
              .collection('trips')
              .doc(tripId)
              .get();

      tripType = (tripDoc['tripType'] as String).toLowerCase();
      trip = tripDoc['trip'] as String;

      Map<String, dynamic>? existingAnswers =
          (tripDoc.data() as Map<String, dynamic>)['tripDetails'];

      for (String question in baseQuestions) {
        controllers[question] = TextEditingController(
          text: existingAnswers?[question] ?? '',
        );
      }

      controllers['startDate'] = TextEditingController(
        text: existingAnswers?['startDate'] ?? '',
      );
      controllers['endDate'] = TextEditingController(
        text: existingAnswers?['endDate'] ?? '',
      );

      for (String question in tripQuestions[tripType] ?? []) {
        controllers[question] = TextEditingController(
          text: existingAnswers?[question] ?? '',
        );
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

    await FirebaseFirestore.instance.collection('trips').doc(tripId!).update({
      'tripDetails': answers,
    });
  }

  Future<void> _deleteTrip() async {
    if (tripId == null) return;

    await FirebaseFirestore.instance.collection('trips').doc(tripId!).delete();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('tripId');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Trip deleted.")));
  }

  Future<bool> _handleBackNavigation() async {
    final startDateFilled = controllers['startDate']?.text.isNotEmpty ?? false;
    final endDateFilled = controllers['endDate']?.text.isNotEmpty ?? false;

    if (!startDateFilled || !endDateFilled) {
      bool? confirmExit = await showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text("Incomplete Trip"),
              content: Text(
                "You haven’t filled in your travel dates. If you go back now, your trip will be deleted. Do you want to continue?",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text("Stay"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    "Leave & Delete",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
      );

      if (confirmExit == true) {
        await _deleteTrip();
        return true;
      } else {
        return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (tripType == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final questions = [...baseQuestions, ...(tripQuestions[tripType] ?? [])];

    return WillPopScope(
      onWillPop: _handleBackNavigation,
      child: Scaffold(
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
                  title: const Text(
                    "Trip Planner",
                    style: TextStyle(color: Colors.black),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.black),
                      onPressed:
                          tripId == null
                              ? null
                              : () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => EditTripDetailsPage(
                                          tripId: tripId!,
                                        ),
                                  ),
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
                    onPageChanged:
                        (index) => setState(() => _currentPage = index),
                    itemBuilder: (context, index) {
                      final question = questions[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 20,
                        ),
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
                                if (question ==
                                    "What are your travel dates (start and end)?")
                                  Column(
                                    children: [
                                      _buildDatePickerField(
                                        "Start Date",
                                        'startDate',
                                      ),
                                      SizedBox(height: 12),
                                      _buildDatePickerField(
                                        "End Date",
                                        'endDate',
                                      ),
                                    ],
                                  )
                                else if (predefinedOptions.containsKey(
                                  question,
                                ))
                                  _buildDropdownFieldWithOptions(
                                    controllers[question]!,
                                    predefinedOptions[question]!,
                                    "Select an option",
                                  )
                                else
                                  _buildInputField(
                                    "Your Answer",
                                    controllers[question],
                                  ),
                                SizedBox(height: 40),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (index > 0)
                                      _navButton(
                                        "Back",
                                        Colors.grey.shade400,
                                        () {
                                          _pageController.previousPage(
                                            duration: Duration(
                                              milliseconds: 300,
                                            ),
                                            curve: Curves.easeInOut,
                                          );
                                        },
                                      ),
                                    if (index < questions.length - 1)
                                      _navButton(
                                        "Next",
                                        Colors.blueAccent,
                                        () async {
                                          await _saveResponses();
                                          _pageController.nextPage(
                                            duration: Duration(
                                              milliseconds: 300,
                                            ),
                                            curve: Curves.easeInOut,
                                          );
                                        },
                                      ),
                                    if (index == questions.length - 1)
                                      _navButton(
                                        "Finish",
                                        Colors.green,
                                        () async {
                                          await _saveResponses();

                                          // ✅ Mark trip as finished
                                          if (tripId != null) {
                                            await FirebaseFirestore.instance
                                                .collection('trips')
                                                .doc(tripId!)
                                                .update({'status': 'finished'});
                                          }

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                "Trip marked as finished!",
                                              ),
                                            ),
                                          );
                                        },
                                      ),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.deepPurple),
        ),
      ),
    );
  }

  Widget _buildDatePickerField(String label, String key) {
    return TextField(
      controller: controllers[key],
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.black87),
        filled: true,
        fillColor: Colors.white.withOpacity(0.7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime(2100),
        );
        if (pickedDate != null) {
          controllers[key]?.text = pickedDate.toString().split(' ')[0];

          // Save responses so far
          await _saveResponses();

          final startFilled =
              controllers['startDate']?.text.isNotEmpty ?? false;
          final endFilled = controllers['endDate']?.text.isNotEmpty ?? false;

          if (startFilled && endFilled && tripId != null) {
            await FirebaseFirestore.instance
                .collection('trips')
                .doc(tripId!)
                .update({'status': 'finish'});

            // ✅ Navigate to InterestPage if AI trip
            if (trip?.toLowerCase() == 'ai trip') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => InterestPage()),
              );
            }
          }
        }
      },
    );
  }

  Widget _buildDropdownFieldWithOptions(
    TextEditingController controller,
    List<String> options,
    String label,
  ) {
    return DropdownButtonFormField<String>(
      value: controller.text.isEmpty ? options[0] : controller.text,
      items:
          options.map((option) {
            return DropdownMenuItem(value: option, child: Text(option));
          }).toList(),
      onChanged: (value) {
        controller.text = value ?? '';
      },
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withOpacity(0.7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _navButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(text, style: TextStyle(fontSize: 16)),
    );
  }
}
