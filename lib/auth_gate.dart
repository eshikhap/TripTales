// import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
// import 'package:firebase_ui_auth/firebase_ui_auth.dart';
// import 'package:flutter/material.dart';

// import 'home_page.dart';

// class AuthGate extends StatelessWidget {
//   const AuthGate({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<User?>(
//       stream: FirebaseAuth.instance.authStateChanges(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return SignInScreen(
//             providers: [
//               EmailAuthProvider(),
//             ],
//             headerBuilder: (context, constraints, shrinkOffset) {
//               return Padding(
//                 padding: const EdgeInsets.all(20),
//                 child: AspectRatio(
//                   aspectRatio: 1,
//                   child: Image.asset('flutterfire_300x.png'),
//                 ),
//               );
//             },
//             subtitleBuilder: (context, action) {
//               return Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 8.0),
//                 child: action == AuthAction.signIn
//                     ? const Text('Welcome to FlutterFire, please sign in!')
//                     : const Text('Welcome to Flutterfire, please sign up!'),
//               );
//             },
//             footerBuilder: (context, action) {
//               return const Padding(
//                 padding: EdgeInsets.only(top: 16),
//                 child: Text(
//                   'By signing in, you agree to our terms and conditions.',
//                   style: TextStyle(color: Colors.grey),
//                 ),
//               );
//             },
//             sideBuilder: (context, shrinkOffset) {
//               return Padding(
//                 padding: const EdgeInsets.all(20),
//                 child: AspectRatio(
//                   aspectRatio: 1,
//                   child: Image.asset('flutterfire_300x.png'),
//                 ),
//               );
//             },
//           );
//         }
//         return HomePage();
//       },
//     );
//   }
// }
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'home_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<void> _storeUserData(User user) async {
    DocumentReference userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

    // Check if user data already exists
    DocumentSnapshot docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      await userDoc.set({
        'id': user.uid,
        'name': user.displayName ?? '',
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print("User data stored in Firestore!");
    } else {
      print("User already exists in Firestore.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SignInScreen(
            providers: [
              EmailAuthProvider(),
            ],
            headerBuilder: (context, constraints, shrinkOffset) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset('flutterfire_300x.png'),
                ),
              );
            },
            subtitleBuilder: (context, action) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: action == AuthAction.signIn
                    ? const Text('Welcome to FlutterFire, please sign in!')
                    : const Text('Welcome to FlutterFire, please sign up!'),
              );
            },
            footerBuilder: (context, action) {
              return const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'By signing in, you agree to our terms and conditions.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            },
            sideBuilder: (context, shrinkOffset) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset('flutterfire_300x.png'),
                ),
              );
            },
          );
        }

        // Store user in Firestore if it's their first time logging in
        _storeUserData(snapshot.data!);

        return HomePage();
      },
    );
  }
}
