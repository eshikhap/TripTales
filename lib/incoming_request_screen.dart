import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:async/async.dart';

class IncomingRequestsScreen extends StatelessWidget {
  final Map<String, dynamic> currentUser;
  const IncomingRequestsScreen({required this.currentUser});

  Future<void> _acceptRequest({
    required String requestId,
    required String fromUid,
    required String type,
    String? tripId,
  }) async {
    final firestore = FirebaseFirestore.instance;

    if (type == 'friend') {
      await firestore.collection('friend_requests').doc(requestId).update({'status': 'accepted'});

      await firestore.collection('users').doc(currentUser['uid']).update({
        'friends': FieldValue.arrayUnion([fromUid]),
      });

      await firestore.collection('users').doc(fromUid).update({
        'friends': FieldValue.arrayUnion([currentUser['uid']]),
      });
    } else if (type == 'trip') {
      await firestore.collection('trip_requests').doc(requestId).update({'status': 'accepted'});

      if (tripId != null) {
        await firestore.collection('trips').doc(tripId).update({
          'members': FieldValue.arrayUnion([currentUser['uid']]),
        });
      }
    }
  }

  Future<void> _rejectRequest({
    required String requestId,
    required String type,
  }) async {
    final collection = type == 'friend' ? 'friend_requests' : 'trip_requests';
    await FirebaseFirestore.instance.collection(collection).doc(requestId).update({
      'status': 'rejected',
    });
  }

  Stream<List<Map<String, dynamic>>> _getCombinedRequests() async* {
    final friendStream = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('toUid', isEqualTo: currentUser['uid'])
        .where('status', isEqualTo: 'pending')
        .snapshots();

    final tripStream = FirebaseFirestore.instance
        .collection('trip_requests')
        .where('toUid', isEqualTo: currentUser['uid'])
        .where('status', isEqualTo: 'pending')
        .snapshots();

    await for (final combined in StreamZip([
      friendStream,
      tripStream,
    ])) {
      final friendRequests = combined[0].docs.map((doc) => {
            'id': doc.id,
            'type': 'friend',
            ...doc.data() as Map<String, dynamic>,
          });

      final tripRequests = combined[1].docs.map((doc) => {
            'id': doc.id,
            'type': 'trip',
            ...doc.data() as Map<String, dynamic>,
          });

      yield [...friendRequests, ...tripRequests];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Incoming Requests')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getCombinedRequests(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final requests = snapshot.data!;
          if (requests.isEmpty) return Center(child: Text("No incoming requests"));

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final fromUid = request['fromUid'];
              final type = request['type'];
              final requestId = request['id'];
              final tripId = request['tripId']; // may be null for friend requests

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(fromUid).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) return SizedBox.shrink();
                  final user = userSnapshot.data!.data() as Map<String, dynamic>;

                  final label = type == 'friend'
                      ? 'Friend request'
                      : 'Trip invitation';

                  return ListTile(
                    title: Text(user['name']),
                    subtitle: Text('$label from ${user['email']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () => _acceptRequest(
                            requestId: requestId,
                            fromUid: fromUid,
                            type: type,
                            tripId: type == 'trip' ? tripId : null,
                          ),
                          child: Text('Accept'),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _rejectRequest(
                            requestId: requestId,
                            type: type,
                          ),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: Text('Reject'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
