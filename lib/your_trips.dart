import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trip_chat_page.dart';
import 'document_trip.dart'; // Import your PDF generation function
class YourTripsPage extends StatelessWidget {
  const YourTripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? "";
    
    return Scaffold(
      appBar: AppBar(title: Text("Your Trips")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('trips')
            .where('members', arrayContains: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No trips found."));
          }
          
          final trips = snapshot.data!.docs;
          
          return ListView.builder(
            itemCount: trips.length,
            itemBuilder: (context, index) {
              var trip = trips[index];
              String tripId = trip['tripId'];
              
              return ListTile(
                title: Text("Trip ID: $tripId"),
                subtitle: Text("Created by: ${trip['creator']}"),
                trailing: Icon(Icons.more_vert),
                onTap: () {
                  _showOptionsDialog(context, tripId);
                },
              );
            },
          );
        },
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
    final safeContext = context; // Save the valid context before popping
    Navigator.pop(context);

    Future.delayed(Duration(milliseconds: 300), () {
      generateAndShareTripAlbum(safeContext, tripId);
    });
  },
  child: Text("Generate Album"),
)



          ],
        );
      },
    );
  }
}
