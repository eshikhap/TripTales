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

            final trips = snapshot.data!.docs;

            return ListView.builder(
              itemCount: trips.length,
              itemBuilder: (context, index) {
                var trip = trips[index];
                String tripId = trip['tripId'];
                String creator = trip['creator'] ?? 'Unknown';

                // Safely extract trip name from nested map
                Map<String, dynamic>? tripDetails = trip['tripDetails'];
                String title = tripDetails?['Give a name to your trip'] ?? 'Unnamed Trip';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Created by: $creator"),
                    trailing: const Icon(Icons.more_vert),
                    onTap: () => _showOptionsDialog(context, tripId),
                  ),
                );
              },
            );
          },
        ),
      ),
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
