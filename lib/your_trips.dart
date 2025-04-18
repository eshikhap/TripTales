import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trip_chat_page.dart';
import 'document_trip.dart';

class YourTripsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      appBar: AppBar(title: Text("Your Trips")),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF93A5CF), Color(0xFFE4EFE9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('trips')
              .where('members', arrayContains: userId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No trips found."));
            }

            final now = DateTime.now();
            final ongoing = <QueryDocumentSnapshot>[];
            final upcoming = <QueryDocumentSnapshot>[];
            final completed = <QueryDocumentSnapshot>[];

            for (var doc in snapshot.data!.docs) {
              final tripDetails = doc['tripDetails'] as Map<String, dynamic>? ?? {};
              final startStr = tripDetails['startDate'];
              final endStr = tripDetails['endDate'];

              if (startStr == null || endStr == null) continue;

              try {
                final start = DateTime.parse(startStr);
                final end = DateTime.parse(endStr);

                if (now.isBefore(start)) {
                  upcoming.add(doc);
                } else if (now.isAfter(end)) {
                  completed.add(doc);
                } else {
                  ongoing.add(doc);
                }
              } catch (e) {
                print("Date parse error in ${doc.id}: $e");
              }
            }

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                if (ongoing.isNotEmpty)
                  _buildTripSection("Ongoing Trips", ongoing, context, Colors.green),
                if (upcoming.isNotEmpty)
                  _buildTripSection("Upcoming Trips", upcoming, context, Colors.blue),
                if (completed.isNotEmpty)
                  _buildTripSection("Completed Trips", completed, context, Colors.grey),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTripSection(String title, List<QueryDocumentSnapshot> trips, BuildContext context, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            title,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accentColor),
          ),
        ),
        ...trips.map((trip) {
          final data = trip.data() as Map<String, dynamic>;
          final tripDetails = data['tripDetails'] as Map<String, dynamic>? ?? {};
          final tripId = data['tripId'] ?? '';
          final creatorUid = data['creator'] ?? '';
          final tripName = tripDetails['Give a name to your trip'] ?? 'Unnamed Trip';
          final destination = tripDetails['Where are you traveling to?'] ?? 'Unknown';
          final start = tripDetails['startDate'] ?? '';
          final end = tripDetails['endDate'] ?? '';

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(creatorUid).get(),
            builder: (context, userSnapshot) {
              String creatorName = 'Loading...';
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                creatorName = userSnapshot.data!['name'] ?? 'Unknown';
              } else if (userSnapshot.hasError) {
                creatorName = 'Error loading name';
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: Text(tripName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Destination: $destination"),
                          Text("Dates: $start → $end"),
                          Text("Created by: $creatorName"),
                        ],
                      ),
                    ),
                    trailing: Icon(Icons.more_vert, color: accentColor),
                    onTap: () => _showOptionsDialog(context, tripId),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ],
    );
  }

  void _showOptionsDialog(BuildContext context, String tripId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Choose an option"),
          content: Text("Would you like to open chat or generate a PDF for this trip?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TripChatPage(tripId: tripId),
                  ),
                );
              },
              child: Text("Open Chat"),
            ),
            TextButton(
              onPressed: () {
                final safeContext = context;
                Navigator.pop(context);
                Future.delayed(Duration(milliseconds: 300), () {
                  generateAndShareTripAlbum(safeContext, tripId);
                });
              },
              child: Text("Generate Album"),
            ),
          ],
        );
      },
    );
  }
}
