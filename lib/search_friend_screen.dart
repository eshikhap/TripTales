import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'email_service.dart'; // Make sure the path is correct

class SearchFriendsScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const SearchFriendsScreen({required this.currentUser});

  @override
  State<SearchFriendsScreen> createState() => _SearchFriendsScreenState();
}

class _SearchFriendsScreenState extends State<SearchFriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];

  void _searchUsers(String query) async {
    final result =
        await FirebaseFirestore.instance
            .collection('users')
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: query + '\uf8ff')
            .get();

    setState(() {
      _results =
          result.docs
              .map(
                (doc) => {'uid': doc.id, ...doc.data() as Map<String, dynamic>},
              )
              .where((user) => user['uid'] != widget.currentUser['uid'])
              .toList();
    });
  }

  Future<void> _sendFriendRequest(Map<String, dynamic> user) async {
     print("Sending friend request to: ${user['name']} (${user['uid']})");
    final request = await FirebaseFirestore.instance
        .collection('friend_requests')
        .add({
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
    final request = await FirebaseFirestore.instance
        .collection('trip_requests')
        .add({
          'fromUid': widget.currentUser['uid'],
          'toUid': user['uid'],
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
      tripName:
          'Amazing Adventure Trip', // Optional: use a variable for dynamic trip names
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

    final DynamicLinkParameters parameters = DynamicLinkParameters(
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

    final shortLink = await FirebaseDynamicLinks.instance.buildShortLink(
      parameters,
    );
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
                hintText: 'Search by name',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () => _searchUsers(_searchController.text.trim()),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
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
                    itemBuilder:
                        (context) => [
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
    );
  }
}
