import 'package:flutter/material.dart';

class RoundedBox extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const RoundedBox({super.key, required this.title, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
  return GestureDetector(
    onTap:onTap,
    child: Container(
      width: MediaQuery.of(context).size.width * 0.8, // 80% of screen width
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8), // Semi-transparent white
        borderRadius: BorderRadius.circular(20), // Rounded Corners
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            spreadRadius: 2,
            offset: Offset(2, 5), // Shadow effect
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: Colors.blueAccent),
          SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    ),
  );
   
  }
}
