import 'package:flutter/material.dart';
import 'planTrip2.dart';
import 'box.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class plantrip1 extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
 final FirebaseAuth _auth = FirebaseAuth.instance;

  const plantrip1({super.key});

  // Function to store trip selection in Firestore and save Trip ID locally
 Future<void> _storeTripSelection(String tripType) async {
  // Create a new document reference
  DocumentReference tripRef = _firestore.collection('trips').doc();
  String userId = _auth.currentUser?.uid ?? "";
  String tripId = tripRef.id; // Get the generated document ID

  // Set all data in the same document
  await tripRef.set({
    'tripId': tripId,
    'tripType': tripType,
    'creator': userId,
     'members': [userId],
    'timestamp': FieldValue.serverTimestamp(),
  });

  // Save Trip ID locally
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('tripId', tripId);

  print("Trip stored with ID: $tripId");
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "TripTales",
          style: TextStyle(
            fontSize: 24, // Change size
            fontWeight: FontWeight.bold, // Make text bold
            fontFamily: 'Roboto', // Change font family if needed
            letterSpacing: 1.5, // Add spacing between letters
          ),
        ),
        centerTitle: true, // Centers the title
        backgroundColor: Colors.transparent, // Makes AppBar transparent
        elevation: 0, // Removes shadow from AppBar
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF93A5CF), Color(0xFFE4EFE9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RoundedBox(
                title: "Plan a Trip Manually",
                icon: Icons.map,
                onTap: ()async {
                  await _storeTripSelection("Manual Trip");
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => plantrip2()),
                  );
                },
              ),
              SizedBox(height: 20),
              RoundedBox(
                title: "Plan Trip with AI",
                icon: Icons.auto_mode,
                onTap: () async{
                   await _storeTripSelection("AI Trip");
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => plantrip2()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
