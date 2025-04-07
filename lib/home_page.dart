import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'auth_gate.dart';
import 'map.dart';
import 'Plan_trip/planTrip1.dart';
import 'incoming_request_screen.dart';
import 'dynamic_link.dart';
import 'your_trips.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  final PageController _trendingPageController = PageController(viewportFraction: 0.85);
  final PageController _savedPageController = PageController(viewportFraction: 0.85);

  final List<Map<String, String>> trendingPlaces = [
    {"title": "Bali", "image": "assets/bali.jpg"},
    {"title": "Paris", "image": "assets/paris.jpg"},
    {"title": "Tokyo", "image": "assets/tokyo.jpg"},
    {"title": "Japan", "image": "assets/japan.jpg"},
    {"title": "Delhi", "image": "assets/delhi.jpg"},
  ];

  final List<Map<String, String>> savedPlaces = [
    {"title": "London", "image": "assets/london.jpg"},
    {"title": "New York", "image": "assets/newyork.jpg"},
    {"title": "Sydney", "image": "assets/sydney.jpg"},
    {"title": "Tokyo", "image": "assets/tokyo.jpg"},
    {"title": "Japan", "image": "assets/japan.jpg"},
  ];
final FlutterLocalNotificationsPlugin _notificationsPlugin =
    FlutterLocalNotificationsPlugin();

@override
void initState() {
  super.initState();
  _initializeAppLogic();
}

Future<void> _initializeAppLogic() async {
  final user = FirebaseAuth.instance.currentUser;

  // Init notifications
  await _initializeNotifications();

  // Init dynamic links if user is signed in
  if (user != null) {
    final userMap = {
      'uid': user.uid,
      'email': user.email,
      'name': user.displayName ?? 'No Name',
    };
    initDynamicLinks(context, userMap);
    _checkTripsAndNotify(); // Only check for trips if user is signed in
  }
}

Future<void> _initializeNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings settings =
      InitializationSettings(android: androidSettings);

  await _notificationsPlugin.initialize(settings);

  // Android 13+ requires explicit permission
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

Future<void> _checkTripsAndNotify() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final tripsQuery = await FirebaseFirestore.instance
      .collection('trips')
      .where('members', arrayContains: user.uid)
      .get();

  final today = DateTime.now();

  for (final trip in tripsQuery.docs) {
    final data = trip.data();
    final startDate = (data['startDate'] as Timestamp).toDate();
    final endDate = (data['endDate'] as Timestamp).toDate();
    final location = data['location'] ?? '';
    final title = data['title'] ?? 'Trip';

    if (!today.isBefore(startDate) && !today.isAfter(endDate)) {
      final dayNumber = today.difference(startDate).inDays + 1;
      final places = List<String>.from(data['places'] ?? []);

      String todayPlace = (dayNumber <= places.length)
          ? places[dayNumber - 1]
          : 'Explore Freely';

      await _showNotification(
        title: "Day $dayNumber of $title!",
        body: "Today’s suggested place in $location: $todayPlace",
      );
    }
  }
}

Future<void> _showNotification({
  required String title,
  required String body,
}) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'trip_channel',
    'Trip Reminders',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidDetails);

  await _notificationsPlugin.show(0, title, body, notificationDetails);
}


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
              plantrip1(),
              Center(child: Text("Document a Trip Page Coming Soon")),
              YourTripsPage(),
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
            leading: Icon(Icons.group_add),
            title: Text("Incoming Requests"),
            onTap: () {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncomingRequestsScreen(
          currentUser: {
            'uid': user.uid,
            'email': user.email,
            'name': user.displayName ?? 'No Name',
          },
        ),
      ),
    );
  }
},

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
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => AuthGate()),
              );
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
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.notifications, color: Colors.black),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.account_circle, color: Colors.black),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ],
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
