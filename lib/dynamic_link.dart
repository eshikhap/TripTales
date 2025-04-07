import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> initDynamicLinks(BuildContext context, Map<String, dynamic> currentUser) async {
  FirebaseDynamicLinks.instance.onLink.listen((dynamicLinkData) async {
    final Uri deepLink = dynamicLinkData.link;
    final action = deepLink.queryParameters['action'];
    final requestId = deepLink.queryParameters['requestId'];
    final fromUid = deepLink.queryParameters['fromUid'];
    final type = deepLink.queryParameters['type']; // 'friend' or 'trip_invite'

    try {
      if (type == 'friend') {
        if (action == 'accept') {
          await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).update({
            'status': 'accepted',
          });
          await FirebaseFirestore.instance.collection('users').doc(currentUser['uid']).update({
            'friends': FieldValue.arrayUnion([fromUid])
          });
          await FirebaseFirestore.instance.collection('users').doc(fromUid!).update({
            'friends': FieldValue.arrayUnion([currentUser['uid']])
          });

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Friend request accepted!')));
        } else if (action == 'reject') {
          await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).update({
            'status': 'rejected',
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Friend request rejected.')));
        }
      } else if (type == 'trip_invite') {
        if (action == 'accept') {
          await FirebaseFirestore.instance.collection('Trip_requests').doc(requestId).update({
            'status': 'accepted',
          });
          // You can optionally store accepted trip IDs on the user document here
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Trip invite accepted!')));
        } else if (action == 'reject') {
          await FirebaseFirestore.instance.collection('Trip_requests').doc(requestId).update({
            'status': 'rejected',
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Trip invite rejected.')));
        }
      }
    } catch (e) {
      print('❌ Error processing dynamic link: $e');
    }
  }).onError((error) {
    print('Dynamic link failed: $error');
  });
}

Future<String> createDynamicLink({
  required String action,
  required String requestId,
  required String fromUid,
  required String type, // 'friend' or 'trip_invite'
}) async {
  final Uri link = Uri.parse(
    'https://triptale.app/friend-response'
    '?action=$action'
    '&requestId=$requestId'
    '&fromUid=$fromUid'
    '&type=$type',
  );

  final DynamicLinkParameters parameters = DynamicLinkParameters(
    uriPrefix: 'https://triptale.page.link',
    link: link,
    androidParameters: AndroidParameters(
      packageName: 'com.example.triptale',
      minimumVersion: 1,
    ),
    iosParameters: IOSParameters(
      bundleId: 'com.example.triptale',
      minimumVersion: '1.0.1',
    ),
  );

  final ShortDynamicLink shortLink = await FirebaseDynamicLinks.instance.buildShortLink(parameters);
  return shortLink.shortUrl.toString();
}
