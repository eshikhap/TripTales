import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'planTrip3.dart'; // Adjust path if needed

class plantrip2 extends StatefulWidget {
  @override
  _plantrip2State createState() => _plantrip2State();
}

class _plantrip2State extends State<plantrip2> with SingleTickerProviderStateMixin {
  String? tripId;
  User? user;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    _getTripId();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();
  }

  Future<void> _getTripId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      tripId = prefs.getString('tripId');
    });
    print("Fetched Trip ID: $tripId");
  }

  Future<void> _updateTripType(String tripType) async {
    if (tripId == null) {
      print("No Trip ID found!");
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).update({
        'tripType': tripType,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print("Trip type updated: $tripType for Trip ID: $tripId");
    } catch (error) {
      print("Error updating trip type: $error");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null || tripId == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentUserMap = {
      'uid': user!.uid,
      'email': user!.email,
      'name': user!.displayName ?? 'No Name',
    };

    return WillPopScope(
      onWillPop: () async {
        if (tripId != null) {
          final doc = await FirebaseFirestore.instance.collection('trips').doc(tripId).get();
          final tripData = doc.data();

          // Check if tripDetails or startDate is missing
          if (tripData == null ||
              tripData['tripDetails'] == null ||
              tripData['tripDetails']['startDate'] == null) {
            bool? shouldExit = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text("Incomplete Trip"),
                content: Text(
                    "You haven't entered trip dates yet. If you go back now, the trip will be deleted. Do you want to continue?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text("Stay"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text("Delete & Exit"),
                  ),
                ],
              ),
            );

            if (shouldExit == true) {
              await FirebaseFirestore.instance.collection('trips').doc(tripId).delete();
              print("Deleted incomplete trip with ID: $tripId");
              return true;
            } else {
              return false;
            }
          }
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "TripTales",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
              letterSpacing: 1.5,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        extendBodyBehindAppBar: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF93A5CF), Color(0xFFE4EFE9)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAnimatedBox("Family Trip", Icons.family_restroom, () {
                  _updateTripType("family");
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) =>
                        SearchFriendsScreen(currentUser: currentUserMap, tripId: tripId!),
                  ));
                }),
                SizedBox(height: 40),
                _buildAnimatedBox("Friends Trip", Icons.group, () {
                  _updateTripType("friends");
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) =>
                        SearchFriendsScreen(currentUser: currentUserMap, tripId: tripId!),
                  ));
                }),
                SizedBox(height: 40),
                _buildAnimatedBox("Solo Trip", Icons.person, () {
                  _updateTripType("solo");
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) =>
                        SearchFriendsScreen(currentUser: currentUserMap, tripId: tripId!),
                  ));
                }),
                SizedBox(height: 40),
                _buildAnimatedBox("Business Trip", Icons.business_center, () {
                  _updateTripType("business");
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) =>
                        SearchFriendsScreen(currentUser: currentUserMap, tripId: tripId!),
                  ));
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBox(String title, IconData icon, VoidCallback onTap) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      width: MediaQuery.of(context).size.width * 0.85,
      padding: EdgeInsets.symmetric(vertical: 25, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            spreadRadius: 3,
            offset: Offset(4, 6),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.blueAccent),
            SizedBox(width: 15),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
