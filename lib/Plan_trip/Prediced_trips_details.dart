import 'package:flutter/material.dart';

class NextPage extends StatelessWidget {
  final List<String> interests;
  NextPage({required this.interests});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Your Interests")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: interests.map((e) => ListTile(title: Text(e))).toList(),
        ),
      ),
    );
  }
}
