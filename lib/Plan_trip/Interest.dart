import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'Prediced_trips_details.dart';

class InterestPage extends StatefulWidget {
  @override
  _InterestPageState createState() => _InterestPageState();
}

class _InterestPageState extends State<InterestPage> {
  String? tripId;
  String? tripType;
  String? destination;
  String? startDate;
  String? endDate;

  List<String> suggestedInterests = [];
  List<String> selectedInterests = [];
  TextEditingController customInterestController = TextEditingController();

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchTripDetails();
  }

  Future<void> _fetchTripDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    tripId = prefs.getString('tripId');

    if (tripId != null) {
      DocumentSnapshot doc =
          await FirebaseFirestore.instance
              .collection('trips')
              .doc(tripId)
              .get();

      final data = doc.data() as Map<String, dynamic>;
      final details = data['tripDetails'] ?? {};

      tripType = data['tripType'];
      destination = details['Where are you traveling to?'];
      startDate = details['startDate'];
      endDate = details['endDate'];

      await _fetchInterestSuggestions();
    }
  }

  Future<void> _fetchInterestSuggestions() async {
    final prompt =
        "Suggest 10 interest categories for a ${tripType} trip to ${destination} between ${startDate} and ${endDate}. The suggestions should be suitable for all age groups and formatted as a single line, comma-separated list without bullet points, numbers, or newlines. Do not include any additional explanation or formatting.";

    final uri = Uri.parse("https://api.perplexity.ai/chat/completions");
    final headers = {
      "Authorization":
          "Bearer Your-Perplexity-API-Key", // Replace with your API key
      "Content-Type": "application/json",
    };
    final body = jsonEncode({
      "model": "sonar", // or "sonar-small-online", depending on your access
      "search_context_size": "high",
      "messages": [
        {"role": "system", "content": "Be precise and concise."},
        {"role": "user", "content": prompt},
      ],
      "temperature": 0.7,
    });

    try {
      final response = await http.post(uri, headers: headers, body: body);
      print("Perplexity Response: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        print("Raw interests content: $content");

        List<String> tempList = content.split(',');
        suggestedInterests = [];

        for (var e in tempList) {
          String trimmed = e.toString().trim();
          if (trimmed.isNotEmpty) {
            suggestedInterests.add(trimmed);
          }
        }
        print("Parsed interests: $suggestedInterests");
      } else {
        print("Failed to fetch interests: ${response.statusCode}");
        suggestedInterests = ["Sightseeing", "Local Cuisine", "Museum Visits"];
      }
    } catch (e) {
      print("Error fetching interests: $e");
      suggestedInterests = ["Sightseeing", "Local Cuisine", "Museum Visits"];
    }

    setState(() {
      loading = false;
    });
  }

  Future<void> _saveInterestsAndContinue() async {
    if (tripId != null) {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).update({
        'interests': selectedInterests,
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => NextPage(
                interests: selectedInterests,
              ), // Replace with your next page
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF93A5CF), Color(0xFFE4EFE9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child:
              loading
                  ? Center(child: CircularProgressIndicator())
                  : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Select Your Interests",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 16),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Suggestions:",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      suggestedInterests.map((interest) {
                                        final selected = selectedInterests
                                            .contains(interest);
                                        return FilterChip(
                                          label: Text(interest),
                                          selected: selected,
                                          onSelected: (bool value) {
                                            setState(() {
                                              if (value) {
                                                selectedInterests.add(interest);
                                              } else {
                                                selectedInterests.remove(
                                                  interest,
                                                );
                                              }
                                            });
                                          },
                                        );
                                      }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: customInterestController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: "Add a custom interest",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.add),
                              onPressed: () {
                                final input =
                                    customInterestController.text.trim();
                                if (input.isNotEmpty &&
                                    !selectedInterests.contains(input)) {
                                  setState(() {
                                    selectedInterests.add(input);
                                    customInterestController.clear();
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        if (selectedInterests.isNotEmpty) ...[
                          Text(
                            "Selected Interests:",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                selectedInterests
                                    .map(
                                      (interest) => Chip(
                                        label: Text(interest),
                                        deleteIcon: Icon(Icons.close),
                                        onDeleted: () {
                                          setState(() {
                                            selectedInterests.remove(interest);
                                          });
                                        },
                                      ),
                                    )
                                    .toList(),
                          ),
                          SizedBox(height: 16),
                        ],
                        Spacer(),
                        Center(
                          child: ElevatedButton(
                            onPressed: _saveInterestsAndContinue,
                            child: Text("Continue"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              padding: EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
        ),
      ),
    );
  }
}
