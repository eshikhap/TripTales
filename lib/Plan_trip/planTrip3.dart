// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:cloud_functions/cloud_functions.dart';
// import 'package:firebase_app_check/firebase_app_check.dart';
// import 'planTrip4.dart';

// class plantrip3 extends StatefulWidget {
//   @override
//   _PlanTrip3State createState() => _PlanTrip3State();
// }

// class _PlanTrip3State extends State<plantrip3> {
//   final TextEditingController _searchController = TextEditingController();
//   List<Map<String, dynamic>> searchResults = [];
//   String? currentUserId;
//   String? currentUserName;
//   String? tripId;

//   @override
//   void initState() {
//     super.initState();
//     fetchUserAndTripId();
//   }

//   Future<void> fetchUserAndTripId() async {
//     User? user = FirebaseAuth.instance.currentUser;
//     if (user == null) {
//       print("No user is currently logged in.");
//       return;
//     }

//     currentUserId = user.uid;

//     DocumentSnapshot userDoc =
//         await FirebaseFirestore.instance
//             .collection('users')
//             .doc(currentUserId)
//             .get();

//     currentUserName =
//         userDoc.exists ? userDoc['name'] ?? "Unknown User" : "Unknown User";

//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     tripId = prefs.getString('tripId') ?? await fetchTripIdFromFirestore();

//     if (tripId != null) {
//       await prefs.setString('tripId', tripId!);
//     }

//     setState(() {});

//     print("Current User ID: $currentUserId");
//     print("Current User Name: $currentUserName");
//   }

//   Future<String?> fetchTripIdFromFirestore() async {
//     if (currentUserId == null) return null;

//     QuerySnapshot snapshot =
//         await FirebaseFirestore.instance
//             .collection('trips')
//             .where('owner', isEqualTo: currentUserId)
//             .limit(1)
//             .get();

//     return snapshot.docs.isNotEmpty ? snapshot.docs.first.id : null;
//   }

//   void _searchUsers(String query) async {
//     if (query.isEmpty) {
//       setState(() => searchResults = []);
//       return;
//     }

//     QuerySnapshot result =
//         await FirebaseFirestore.instance
//             .collection('users')
//             .where('email', isGreaterThanOrEqualTo: query.toLowerCase())
//             .where('email', isLessThan: query.toLowerCase() + '\uf8ff')
//             .get();

//     setState(() {
//       searchResults =
//           result.docs
//               .map(
//                 (doc) => {
//                   'id': doc.id,
//                   'name': doc['name'] ?? 'Unknown',
//                   'email': doc['email'],
//                 },
//               )
//               .toList();
//     });
//   }

//   Future<void> sendFriendRequest(String friendId) async {
//     try {
//       User? user = FirebaseAuth.instance.currentUser;
//       if (user == null) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text("You need to be logged in!")));
//         return;
//       }

//       String? idToken = await user.getIdToken(true);
//       String? appCheckToken = await FirebaseAppCheck.instance.getToken();

//       HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
//         'sendFriendRequestEmail',
//         options: HttpsCallableOptions(timeout: Duration(seconds: 10)),
//       );

//       final result = await callable.call({
//         'from': user.uid,
//         'to': friendId,
//         'token': idToken,
//         'appCheck': appCheckToken,
//       });

//       print("Success: ${result.data}");
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Friend request sent!")));
//     } catch (e) {
//       print("Error sending friend request: $e");
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Failed to send friend request")));
//     }
//   }

//   Future<void> inviteToTrip(String friendId) async {
//     try {
//       User? user = FirebaseAuth.instance.currentUser;
//       if (user == null) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text("You need to be logged in!")));
//         return;
//       }

//       if (tripId == null) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text("Trip ID not found!")));
//         return;
//       }

//       String? idToken = await user.getIdToken(true);
//       String? appCheckToken = await FirebaseAppCheck.instance.getToken();

//       HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
//         'sendTripInviteEmail',
//         options: HttpsCallableOptions(timeout: Duration(seconds: 10)),
//       );

//       final result = await callable.call({
//         'from': user.uid,
//         'to': friendId,
//         'tripId': tripId,
//         'token': idToken,
//         'appCheck': appCheckToken,
//       });

//       print("Success: ${result.data}");
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Trip invitation sent!")));
//     } catch (e) {
//       print("Error inviting to trip: $e");
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Failed to invite to trip")));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Search Friends"),
//         centerTitle: true,
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//       ),
//       body: Container(
//         padding: EdgeInsets.all(20),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Color(0xFF93A5CF), Color(0xFFE4EFE9)],
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//           ),
//         ),
//         child: Column(
//           children: [
//             TextField(
//               controller: _searchController,
//               decoration: InputDecoration(
//                 hintText: "Search by email...",
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 prefixIcon: Icon(Icons.search),
//               ),
//               onChanged: _searchUsers,
//             ),
//             SizedBox(height: 20),
//             Expanded(
//               child:
//                   searchResults.isEmpty
//                       ? Center(child: Text("No users found"))
//                       : ListView.builder(
//                         itemCount: searchResults.length,
//                         itemBuilder: (context, index) {
//                           final user = searchResults[index];
//                           return ListTile(
//                             title: Text(user['name']),
//                             subtitle: Text(user['email']),
//                             trailing: PopupMenuButton<String>(
//                               icon: Icon(
//                                 Icons.more_vert,
//                                 size: 30,
//                                 color: Colors.black,
//                               ),
//                               onSelected: (value) {
//                                 if (value == "friend") {
//                                   sendFriendRequest(user['id']);
//                                 } else if (value == "trip") {
//                                   inviteToTrip(user['id']);
//                                 }
//                               },
//                               itemBuilder:
//                                   (context) => [
//                                     PopupMenuItem(
//                                       value: "friend",
//                                       child: Text("Add as Friend"),
//                                     ),
//                                     PopupMenuItem(
//                                       value: "trip",
//                                       child: Text("Invite to Trip"),
//                                     ),
//                                   ],
//                             ),
//                           );
//                         },
//                       ),
//             ),
//           ],
//         ),
//       ),

//       /// ➕ Floating Action Button to continue trip planning
//       floatingActionButton: FloatingActionButton.extended(
//         onPressed: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(builder: (context) => plantrip4()),
//           );
//         },
//         icon: Icon(Icons.arrow_forward),
//         label: Text("Continue"),
//         backgroundColor: Colors.blueAccent,
//       ),
//     );
//   }
// }
// SearchFriendsScreen
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
// import '../email_service.dart'; // Make sure the path is correct
// import 'planTrip4.dart';

// class SearchFriendsScreen extends StatefulWidget {
//   final Map<String, dynamic> currentUser;
//   const SearchFriendsScreen({required this.currentUser});

//   @override
//   State<SearchFriendsScreen> createState() => _SearchFriendsScreenState();
// }

// class _SearchFriendsScreenState extends State<SearchFriendsScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   List<Map<String, dynamic>> _results = [];

//   void _searchUsers(String query) async {
//     final result =
//         await FirebaseFirestore.instance
//             .collection('users')
//             .where('name', isGreaterThanOrEqualTo: query)
//             .where('name', isLessThanOrEqualTo: query + '\uf8ff')
//             .get();

//     setState(() {
//       _results =
//           result.docs
//               .map(
//                 (doc) => {'uid': doc.id, ...doc.data() as Map<String, dynamic>},
//               )
//               .where((user) => user['uid'] != widget.currentUser['uid'])
//               .toList();
//     });
//   }

//   Future<void> _sendFriendRequest(Map<String, dynamic> user) async {
//     print("Sending friend request to: ${user['name']} (${user['uid']})");
//     final request = await FirebaseFirestore.instance
//         .collection('friend_requests')
//         .add({
//           'fromUid': widget.currentUser['uid'],
//           'toUid': user['uid'],
//           'status': 'pending',
//           'timestamp': FieldValue.serverTimestamp(),
//         });

//     final requestId = request.id;

//     final acceptLink = await _createDynamicLink(
//       type: 'friend_request',
//       action: 'accept',
//       requestId: requestId,
//       fromUid: widget.currentUser['uid'],
//     );

//     final rejectLink = await _createDynamicLink(
//       type: 'friend_request',
//       action: 'reject',
//       requestId: requestId,
//       fromUid: widget.currentUser['uid'],
//     );

//     await sendRequestEmail(
//       toName: user['name'],
//       toEmail: user['email'],
//       fromName: widget.currentUser['name'],
//       acceptLink: acceptLink,
//       rejectLink: rejectLink,
//       type: 'friend',
//     );

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Friend request sent to ${user['name']}')),
//     );
//   }

//   Future<void> _sendTripRequest(Map<String, dynamic> user) async {
//     final request = await FirebaseFirestore.instance
//         .collection('trip_requests')
//         .add({
//           'fromUid': widget.currentUser['uid'],
//           'toUid': user['uid'],
//           'status': 'pending',
//           'timestamp': FieldValue.serverTimestamp(),
//         });

//     final requestId = request.id;

//     final acceptLink = await _createDynamicLink(
//       type: 'trip_invite',
//       action: 'accept',
//       requestId: requestId,
//       fromUid: widget.currentUser['uid'],
//     );

//     final rejectLink = await _createDynamicLink(
//       type: 'trip_invite',
//       action: 'reject',
//       requestId: requestId,
//       fromUid: widget.currentUser['uid'],
//     );

//     await sendRequestEmail(
//       toName: user['name'],
//       toEmail: user['email'],
//       fromName: widget.currentUser['name'],
//       acceptLink: acceptLink,
//       rejectLink: rejectLink,
//       type: 'trip',
//       tripName:
//           'Amazing Adventure Trip', // Optional: use a variable for dynamic trip names
//     );

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Trip invite sent to ${user['name']}')),
//     );
//   }

//   Future<String> _createDynamicLink({
//     required String type,
//     required String action,
//     required String requestId,
//     required String fromUid,
//   }) async {
//     final Uri deepLink = Uri.parse(
//       'https://triptale.app/$type-response?action=$action&requestId=$requestId&fromUid=$fromUid',
//     );

//     final DynamicLinkParameters parameters = DynamicLinkParameters(
//       uriPrefix: 'https://triptale.page.link',
//       link: deepLink,
//       androidParameters: AndroidParameters(
//         packageName: 'com.example.triptale',
//         minimumVersion: 1,
//       ),
//       iosParameters: IOSParameters(
//         bundleId: 'com.example.triptale',
//         minimumVersion: '1.0.0',
//       ),
//     );

//     final shortLink = await FirebaseDynamicLinks.instance.buildShortLink(
//       parameters,
//     );
//     return shortLink.shortUrl.toString();
//   }

//   @override
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Search Friends')),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: TextField(
//               controller: _searchController,
//               decoration: InputDecoration(
//                 hintText: 'Search by name',
//                 suffixIcon: IconButton(
//                   icon: Icon(Icons.search),
//                   onPressed: () => _searchUsers(_searchController.text.trim()),
//                 ),
//               ),
//             ),
//           ),
//           Expanded(
//             child: ListView.builder(
//               itemCount: _results.length,
//               itemBuilder: (context, index) {
//                 final user = _results[index];
//                 return ListTile(
//                   title: Text(user['name']),
//                   subtitle: Text(user['email']),
//                   trailing: PopupMenuButton<String>(
//                     onSelected: (value) {
//                       if (value == 'add_friend') _sendFriendRequest(user);
//                       if (value == 'invite_trip') _sendTripRequest(user);
//                     },
//                     itemBuilder:
//                         (context) => [
//                           PopupMenuItem(
//                             value: 'add_friend',
//                             child: Text('Add Friend'),
//                           ),
//                           PopupMenuItem(
//                             value: 'invite_trip',
//                             child: Text('Invite to Trip'),
//                           ),
//                         ],
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//       bottomNavigationBar: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: ElevatedButton(
//           style: ElevatedButton.styleFrom(
//             padding: EdgeInsets.symmetric(vertical: 16),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12),
//             ),
//           ),
//           onPressed: () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => plantrip4(),
//               ), // Replace with your actual next screen
//             );
//           },
//           child: Text('Continue', style: TextStyle(fontSize: 18)),
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import '../email_service.dart'; // Update if needed
import 'planTrip4.dart';

class SearchFriendsScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final String tripId;

  const SearchFriendsScreen({
    required this.currentUser,
    required this.tripId,
  });

  @override
  State<SearchFriendsScreen> createState() => _SearchFriendsScreenState();
}

class _SearchFriendsScreenState extends State<SearchFriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    // Try searching by email first
    final emailQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: query)
        .get();

    if (emailQuery.docs.isNotEmpty) {
      setState(() {
        _results = emailQuery.docs
            .map((doc) => {'uid': doc.id, ...doc.data() as Map<String, dynamic>})
            .where((user) => user['uid'] != widget.currentUser['uid'])
            .toList();
      });
      return;
    }

    // If no email matches, try name search
    final nameQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: query + '\uf8ff')
        .get();

    setState(() {
      _results = nameQuery.docs
          .map((doc) => {'uid': doc.id, ...doc.data() as Map<String, dynamic>})
          .where((user) => user['uid'] != widget.currentUser['uid'])
          .toList();
    });
  }

  Future<void> _sendFriendRequest(Map<String, dynamic> user) async {
    final request = await FirebaseFirestore.instance.collection('friend_requests').add({
      'fromUid': widget.currentUser['uid'],
      'toUid': user['uid'],
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    final requestId = request.id;

    final acceptLink = await _createDynamicLink(
      type: 'friend_request',
      action: 'accept',
      requestId: requestId,
      fromUid: widget.currentUser['uid'],
    );

    final rejectLink = await _createDynamicLink(
      type: 'friend_request',
      action: 'reject',
      requestId: requestId,
      fromUid: widget.currentUser['uid'],
    );

    await sendRequestEmail(
      toName: user['name'],
      toEmail: user['email'],
      fromName: widget.currentUser['name'],
      acceptLink: acceptLink,
      rejectLink: rejectLink,
      type: 'friend',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Friend request sent to ${user['name']}')),
    );
  }

  Future<void> _sendTripRequest(Map<String, dynamic> user) async {
    final request = await FirebaseFirestore.instance.collection('trip_requests').add({
      'fromUid': widget.currentUser['uid'],
      'toUid': user['uid'],
      'tripId': widget.tripId,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    final requestId = request.id;

    final acceptLink = await _createDynamicLink(
      type: 'trip_invite',
      action: 'accept',
      requestId: requestId,
      fromUid: widget.currentUser['uid'],
    );

    final rejectLink = await _createDynamicLink(
      type: 'trip_invite',
      action: 'reject',
      requestId: requestId,
      fromUid: widget.currentUser['uid'],
    );

    await sendRequestEmail(
      toName: user['name'],
      toEmail: user['email'],
      fromName: widget.currentUser['name'],
      acceptLink: acceptLink,
      rejectLink: rejectLink,
      type: 'trip',
      tripName: 'Amazing Adventure Trip',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Trip invite sent to ${user['name']}')),
    );
  }

  Future<String> _createDynamicLink({
    required String type,
    required String action,
    required String requestId,
    required String fromUid,
  }) async {
    final Uri deepLink = Uri.parse(
      'https://triptale.app/$type-response?action=$action&requestId=$requestId&fromUid=$fromUid',
    );

    final parameters = DynamicLinkParameters(
      uriPrefix: 'https://triptale.page.link',
      link: deepLink,
      androidParameters: AndroidParameters(
        packageName: 'com.example.triptale',
        minimumVersion: 1,
      ),
      iosParameters: IOSParameters(
        bundleId: 'com.example.triptale',
        minimumVersion: '1.0.0',
      ),
    );

    final shortLink = await FirebaseDynamicLinks.instance.buildShortLink(parameters);
    return shortLink.shortUrl.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Search Friends')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () => _searchUsers(_searchController.text.trim()),
                ),
              ),
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(child: Text('No users found'))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final user = _results[index];
                      return ListTile(
                        title: Text(user['name']),
                        subtitle: Text(user['email']),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'add_friend') _sendFriendRequest(user);
                            if (value == 'invite_trip') _sendTripRequest(user);
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'add_friend',
                              child: Text('Add Friend'),
                            ),
                            PopupMenuItem(
                              value: 'invite_trip',
                              child: Text('Invite to Trip'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => plantrip4(), // your next screen
              ),
            );
          },
          child: Text('Continue', style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}
