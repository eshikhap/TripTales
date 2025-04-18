import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'home_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isHandlingUser = false;
  bool _userHandled = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        // Not signed in
        if (user == null) {
          _isHandlingUser = false;
          _userHandled = false;

          return SignInScreen(
            providers: [
              EmailAuthProvider(),
            ],
          );
        }

        // Signed in but not yet processed
        if (!_isHandlingUser && !_userHandled) {
          _isHandlingUser = true;
          _processUser(user);
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // All done
        return const HomePage();
      },
    );
  }

  Future<void> _processUser(User user) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    String? name = user.displayName;

    if (name == null || name.isEmpty) {
      name = await _askForName(context);
      if (name != null && name.isNotEmpty) {
        await user.updateDisplayName(name);
      }
    }

    if (!docSnapshot.exists) {
      await userDoc.set({
        'id': user.uid,
        'name': name ?? '',
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    setState(() {
      _userHandled = true;
    });
  }

  Future<String?> _askForName(BuildContext context) async {
    String? name;
    final controller = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('What’s your name?'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                name = controller.text.trim();
                Navigator.of(context).pop();
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    return name;
  }
}
