import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _trendingPageController =
      PageController(viewportFraction: 0.85);
  final PageController _savedPageController =
      PageController(viewportFraction: 0.85);

  final List<Map<String, String>> trendingPlaces = [
    {"title": "Bali", "image": "assets/bali.jpg"},
    {"title": "Paris", "image": "assets/paris.jpg"},
    {"title": "Tokyo", "image": "assets/tokyo.jpg"},
  ];

  final List<Map<String, String>> savedPlaces = [
    {"title": "London", "image": "assets/london.jpg"},
    {"title": "New York", "image": "assets/newyork.jpg"},
    {"title": "Sydney", "image": "assets/sydney.jpg"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF93A5CF), Color(0xFFE4EFE9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreetingSection(),
                SizedBox(height: 15),
                _buildQuoteSection(),
                SizedBox(height: 20),
                _buildSection("Top Picks for You"),
                _buildSlidingPlaces(trendingPlaces, _trendingPageController),
                SizedBox(height: 20),
                _buildSection("Your Saved Places"),
                _buildSlidingPlaces(savedPlaces, _savedPageController),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.sync_alt), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.send), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.article), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ""),
        ],
      ),
    );
  }

  Widget _buildGreetingSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Hello, User",
          style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold), // ⬆ Increased font size
        ),
        IconButton(
          icon: Icon(Icons.notifications, color: Colors.black),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildQuoteSection() {
  return Center(
    child: Container(
      width: 300,
      height: 50, // 🔥 Fixed height to prevent shifting
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 18, // ⬆ Increased font size for readability
          fontWeight: FontWeight.bold,
          color: Colors.black,
          fontStyle: FontStyle.italic,
        ),
        child: AnimatedTextKit(
          animatedTexts: [
            TypewriterAnimatedText(
              '“Travel is the only thing you buy that makes you richer.”',
              speed: Duration(milliseconds: 100),
            ),
          ],
          repeatForever: false, // ✅ No infinite loop
          totalRepeatCount: 1,  // ✅ Ensures it runs only once
        ),
      ),
    ),
  );
}


  Widget _buildSection(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 8),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold), // ⬆ Increased font size
      ),
    );
  }

  Widget _buildSlidingPlaces(
      List<Map<String, String>> places, PageController controller) {
    return Container(
      height: 200,
      child: PageView.builder(
        controller: controller,
        itemCount: places.length,
        itemBuilder: (context, index) {
          return _buildPlaceCard(places, index, controller);
        },
      ),
    );
  }

  Widget _buildPlaceCard(
      List<Map<String, String>> places, int index, PageController controller) {
    return AnimatedBuilder(
      animation: controller, // 🔥 Now both sections use their own controllers
      builder: (context, child) {
        double scale = 1.0;
        if (controller.position.haveDimensions) {
          double pageOffset = controller.page! - index;
          scale = (1 - (pageOffset.abs() * 0.3)).clamp(0.8, 1.0);
        }

        return Transform.scale(
          scale: scale,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              image: DecorationImage(
                image: AssetImage(places[index]["image"]!),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 5,
                  spreadRadius: 2,
                  offset: Offset(2, 4),
                ),
              ],
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  places[index]["title"]!,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize:
                        20, // ⬆ Increased font size for better readability
                    backgroundColor: Colors.black45,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
