import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'auth_gate.dart';
import 'map.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController(); // Fixed missing PageController
  final PageController _trendingPageController = PageController(viewportFraction: 0.85);
  final PageController _savedPageController = PageController(viewportFraction: 0.85);

  final List<Map<String, String>> trendingPlaces = [
    {"title": "Bali", "image": "assets/bali.jpg"},
    {"title": "Paris", "image": "assets/paris.jpg"},
    {"title": "Tokyo", "image": "assets/tokyo.jpg"},
    {"title": "Japan", "image": "assets/japan.jpg"},  // Fixed duplicate names
    {"title": "Delhi", "image": "assets/delhi.jpg"},
  ];

  final List<Map<String, String>> savedPlaces = [
    {"title": "London", "image": "assets/london.jpg"},
    {"title": "New York", "image": "assets/newyork.jpg"},
    {"title": "Sydney", "image": "assets/sydney.jpg"},
    {"title": "Tokyo", "image": "assets/tokyo.jpg"},
    {"title": "Japan", "image": "assets/japan.jpg"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildProfileDrawer(),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            children: [
              _buildHomeContent(),
              MapPage(),
              Center(child: Text("Plan a Trip Page Coming Soon")),
              Center(child: Text("Document a Trip Page Coming Soon")),
              Center(child: Text("Your Trip Page Coming Soon")),
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          _pageController.jumpToPage(index);
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Maps"),
          BottomNavigationBarItem(icon: Icon(Icons.flight_takeoff), label: "Plan a Trip"),
          BottomNavigationBarItem(icon: Icon(Icons.article), label: "Document a Trip"),
          BottomNavigationBarItem(icon: Icon(Icons.card_travel), label: "Your Trip"),
        ],
      ),
    );
  }

  Widget _buildProfileDrawer() {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user?.displayName ?? "Guest User"),
            accountEmail: Text(user?.email ?? "No email available"),
            currentAccountPicture: CircleAvatar(
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : AssetImage("assets/profile_placeholder.png") as ImageProvider,
            ),
            decoration: BoxDecoration(color: Colors.blueAccent),
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text("Settings"),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text("Sign Out", style: TextStyle(color: Colors.red)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AuthGate()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return Container(
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
              _buildSection("Your saved Places"),
              _buildSlidingPlaces(savedPlaces, _savedPageController),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Hello, Traveler",
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
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
        height: 50,
        child: DefaultTextStyle(
          style: TextStyle(
            fontSize: 18,
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
              TypewriterAnimatedText(
                '“Adventure awaits, go find it.”',
                speed: Duration(milliseconds: 100),
              ),
            ],
            repeatForever: true,
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
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSlidingPlaces(List<Map<String, String>> places, PageController controller) {
    return Container(
      height: 200,
      child: PageView.builder(
        controller: controller,
        itemCount: places.length,
        itemBuilder: (context, index) {
          return _buildPlaceCard(places, index);
        },
      ),
    );
  }

  Widget _buildPlaceCard(List<Map<String, String>> places, int index) {
    return Container(
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
              fontSize: 20,
              backgroundColor: Colors.black45,
            ),
          ),
        ),
      ),
    );
  }
}
