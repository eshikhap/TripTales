import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'auth_gate.dart';
import 'map.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'Plan_trip/planTrip1.dart';
import 'incoming_request_screen.dart';
import 'dynamic_link.dart';
import 'your_trips.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
// ignore: unused_import
import 'trip_chat_page.dart';
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final PageController _trendingPageController = PageController(
    viewportFraction: 0.85,
  );

  // ignore: unused_field
  final PageController _savedPageController = PageController(
    viewportFraction: 0.85,
  );

  List<Map<String, String>> topPicks = [];
  List<Map<String, String>> savedPlaces = [];
  String? error;
  List<Map<String, String>> favoritePlaces = [];

  late final PageController pageController = PageController();

  bool _isFavorite(Map<String, String> place) {
    return favoritePlaces.any((fav) => fav["title"] == place["title"]);
  }

  // ignore: unused_element
  void _toggleFavorite(Map<String, String> place) {
    setState(() {
      if (_isFavorite(place)) {
        favoritePlaces.removeWhere((fav) => fav["title"] == place["title"]);
      } else {
        favoritePlaces.add(place);
      }
    });
  }

  @override
  void initState() {
    super.initState();

    _initializeAppLogic();
    _fetchTopPicks();
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
      // ignore: use_build_context_synchronously
      initDynamicLinks(context, userMap);
      _checkTripsAndNotify(); // Only check for trips if user is signed in
    }
  }

  Future<void> _openInGoogleMaps(Map<String, String> place) async {
    try {
      // ignore: duplicate_ignore
      // ignore: deprecated_member_use
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final double userLat = position.latitude;
      final double userLng = position.longitude;

      final double placeLat = double.parse(place['lat']!);
      final double placeLng = double.parse(place['lng']!);

      final Uri uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=$userLat,$userLng&destination=$placeLat,$placeLng&travelmode=driving',
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch Maps';
      }
    } catch (e) {
      print("Failed to open maps: $e");
    }
  }

  Future<void> _fetchTopPicks() async {
    const apiKey =
        'AIzaSyBw1GfQx7suGPPUXdc8p5aWuw5CzdhxrP4'; // Replace with your API key

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          setState(() {
            error = "Location permission not granted";
          });
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String url =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${position.latitude},${position.longitude}&radius=500000&type=tourist_attraction&key=$apiKey';

      final response = await http.get(Uri.parse(url));
      final jsonData = jsonDecode(response.body);

      if (jsonData['status'] == 'OK') {
        List<Map<String, String>> fetchedPicks = [];
        final results = jsonData['results'];

        for (var place in results) {
          if (place['photos'] != null && place['photos'].isNotEmpty) {
            final name = place['name'];
            final photoRef = place['photos'][0]['photo_reference'];
            final photoUrl =
                'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoRef&key=$apiKey';
            final address = place['vicinity'] ?? "Address not available";
            final rating = place['rating']?.toString() ?? "N/A";
            final types =
                (place['types'] as List<dynamic>?)
                    ?.take(3)
                    .map((t) => t.toString().replaceAll('_', ' '))
                    .join(', ') ??
                "No info";

            fetchedPicks.add({
              "title": name ?? "Unknown Place",
              "image": photoUrl,
              "address": address,
              "rating": rating,
              "types": types,
              "lat": place['geometry']['location']['lat'].toString(),
              "lng": place['geometry']['location']['lng'].toString(),
            });

            if (fetchedPicks.length == 5) break;
          }
        }

        setState(() {
          topPicks = fetchedPicks;
          error =
              fetchedPicks.length < 5
                  ? "Only found ${fetchedPicks.length} places with photos"
                  : null;
        });
      } else {
        setState(() {
          error = "Failed to get top picks: ${jsonData['status']}";
        });
      }
    } catch (e) {
      setState(() {
        error = "Error fetching top picks: $e";
      });
    }
  }

Future<void> _initializeNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings settings = InitializationSettings(
    android: androidSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(settings);

  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}


  Future<void> _checkTripsAndNotify() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final tripsQuery =
        await FirebaseFirestore.instance
            .collection('trips')
            .where('members', arrayContains: user.uid)
            .get();

    final today = DateTime.now();
    for (final trip in tripsQuery.docs) {
      final data = trip.data();
      final tripDetails = data['tripDetails'] as Map<String, dynamic>? ?? {};

      final startDateStr = tripDetails['startDate'];
      final endDateStr = tripDetails['endDate'];
      final location = tripDetails['Where are you traveling to?'] ?? '';
      final title = tripDetails['Give a name to your trip'] ?? 'Trip';

      if (startDateStr == null || endDateStr == null) continue;

      try {
        final startDate = DateTime.parse(startDateStr);
        final endDate = DateTime.parse(endDateStr);

        if (!today.isBefore(startDate) && !today.isAfter(endDate)) {
          final dayNumber = today.difference(startDate).inDays + 1;
          final places = List<String>.from(data['places'] ?? []);

          String todayPlace =
              (dayNumber <= places.length)
                  ? places[dayNumber - 1]
                  : 'Explore Freely';

          await _showNotification(
            title: "Day $dayNumber of $title!",
            body: "Today’s suggested place in $location: $todayPlace",
          );
        }
      } catch (e) {
        print("Invalid date format in tripDetails: $e");
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
    channelDescription: 'Notifications about your trip plans',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    notificationDetails,
  );
}

  // @override
  // Widget build(BuildContext context) {
  //   final List<Widget> _pages = [
  //     _buildHomeContent(),
  //     MapPage(),
  //     plantrip1(),
  //     // Center(child: Text("Document a Trip Page Coming Soon")),
  //     YourTripsPage(),
  //   ];

  //   return Scaffold(
  //     drawer: _buildProfileDrawer(),
  //     body: Stack(
  //       children: [
  //         PageView(
  //           controller: pageController,
  //           onPageChanged: (index) {
  //             setState(() {
  //               _selectedIndex = index;
  //             });
  //           },
  //           children: _pages, // Use _pages list for the pages
  //         ),
  //       ],
  //     ),
  //     bottomNavigationBar: BottomNavigationBar(
  //       type: BottomNavigationBarType.fixed,
  //       currentIndex: _selectedIndex,
  //       onTap: (index) {
  //         setState(() => _selectedIndex = index);
  //         pageController.jumpToPage(index);
  //       },
  //       items: const [
  //         BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
  //         BottomNavigationBarItem(icon: Icon(Icons.map), label: "Maps"),
  //         BottomNavigationBarItem(
  //           icon: Icon(Icons.flight_takeoff),
  //           label: "Plan a Trip",
  //         ),
  //         // BottomNavigationBarItem(
  //         //   icon: Icon(Icons.article),
  //         //   label: "Document a Trip",
  //         // ),
  //         BottomNavigationBarItem(
  //           icon: Icon(Icons.card_travel),
  //           label: "Your Trip",
  //         ),
  //       ],
  //     ),
  //   );
  // }
@override
Widget build(BuildContext context) {
  final List<Widget> _pages = [
    _buildHomeContent(),
    MapPage(),
    plantrip1(),
    YourTripsPage(),
  ];

  return Scaffold(
    drawer: _buildProfileDrawer(),
    body: Stack(
      children: [
        PageView(
          controller: pageController,
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          children: _pages,
        ),
      ],
    ),
    bottomNavigationBar: BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() => _selectedIndex = index);
        pageController.jumpToPage(index);
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: "Maps"),
        BottomNavigationBarItem(
          icon: Icon(Icons.flight_takeoff),
          label: "Plan a Trip",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.card_travel),
          label: "Your Trip",
        ),
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
              backgroundImage:
                  user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : AssetImage("assets/profile_placeholder.png")
                          as ImageProvider,
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
                    builder:
                        (context) => IncomingRequestsScreen(
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
      decoration: const BoxDecoration(
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
              const SizedBox(height: 15),
              _buildQuoteSection(),
              const SizedBox(height: 20),
              _buildSection("Top Picks for You"),
              _buildSlidingPlaces(topPicks, _trendingPageController),
              const SizedBox(height: 20),
              _buildSection("Your Saved Trips"),
              SavedTripsSection(),
              if (error != null)
                Text(
                  "Error: $error",
                  style: const TextStyle(color: Colors.red),
                ),
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

  Widget _buildSlidingPlaces(
    List<Map<String, String>> places,
    PageController controller,
  ) {
    if (places.isEmpty) {
      return const Center(child: Text("No top picks found"));
    }

    return SizedBox(
      height: 200,
      child: PageView.builder(
        controller: controller,
        itemCount: places.length,
        itemBuilder: (context, index) {
          return _buildPlaceCard(
            places,
            index,
            controller,
          ); // Pass controller if your card uses it
        },
      ),
    );
  }

  Widget _buildPlaceCard(
    List<Map<String, String>> places,
    int index,
    PageController controller,
  ) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        double scale = 1.0;
        if (controller.position.haveDimensions) {
          double pageOffset = controller.page! - index;
          scale = (1 - (pageOffset.abs() * 0.3)).clamp(0.8, 1.0);
        }

        final imageUrl = places[index]["image"];
        final hasImage = imageUrl != null && imageUrl.startsWith("http");

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlaceDetailPage(place: places[index]),
              ),
            );
          },
          child: Transform.scale(
            scale: scale,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.grey[300],
                image:
                    hasImage
                        ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                        : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 5,
                    spreadRadius: 2,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child:
                  hasImage
                      ? Stack(
                        children: [
                          // Title at bottom left
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                places[index]["title"] ?? "Unknown Place",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  backgroundColor: Colors.black45,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          // Icons at top right
                          Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 8.0,
                                right: 8.0,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Favorite icon
                                  IconButton(
                                    icon: Icon(
                                      _isFavorite(places[index])
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: Colors.red,
                                      size: 24,
                                    ),
                                    onPressed:
                                        () => _toggleFavorite(places[index]),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  // Google Maps icon
                                  IconButton(
                                    icon: const Icon(
                                      Icons.map,
                                      color: Colors.blue,
                                      size: 24,
                                    ),
                                    onPressed:
                                        () => _openInGoogleMaps(places[index]),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                      : const Center(
                        child: Icon(Icons.image, color: Colors.white, size: 40),
                      ),
            ),
          ),
        );
      },
    );
  }
}

class _notificationsPlugin {
  bool _notificationsEnabled = true;

  void disableNotifications() {
    _notificationsEnabled = false;
  }

  void enableNotifications() {
    _notificationsEnabled = true;
  }

  void showNotification(String title, String body) {
    if (!_notificationsEnabled) return;

    // Your actual notification logic here
    print("Showing notification: $title - $body");
  }

  static initialize(InitializationSettings settings) {}

  static show(
    int i,
    String title,
    String body,
    NotificationDetails notificationDetails,
  ) {}
}

class PlaceDetailPage extends StatefulWidget {
  final Map<String, String> place;

  const PlaceDetailPage({super.key, required this.place});

  @override
  _PlaceDetailPageState createState() => _PlaceDetailPageState();
}

class _PlaceDetailPageState extends State<PlaceDetailPage> {
  List<Map<String, String>> nearbyPlaces = [];
  final String apiKey =
      'AIzaSyBw1GfQx7suGPPUXdc8p5aWuw5CzdhxrP4'; // Replace with your actual API key

  @override
  void initState() {
    super.initState();
    fetchNearbyPlaces();
  }

  Future<void> fetchNearbyPlaces() async {
    final lat = widget.place['lat'];
    final lng = widget.place['lng'];
    if (lat == null || lng == null) return;

    final types = ['restaurant', 'lodging'];
    List<Map<String, String>> fetchedPlaces = [];

    for (final type in types) {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=1500&type=$type&key=$apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>;
        for (var result in results) {
          if (fetchedPlaces.length >= 5) break;
          final photoRef =
              result['photos'] != null
                  ? result['photos'][0]['photo_reference']
                  : null;
          final imageUrl =
              photoRef != null
                  ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoRef&key=$apiKey'
                  : null;
          fetchedPlaces.add({
            "name": result['name'] ?? 'Unknown',
            "rating": result['rating']?.toString() ?? 'N/A',
            "image": imageUrl ?? '',
            "type": type,
            "lat": result['geometry']['location']['lat'].toString(),
            "lng": result['geometry']['location']['lng'].toString(),
          });
        }
      }
    }

    setState(() {
      nearbyPlaces = fetchedPlaces;
    });
  }

  void _launchMapsUrl(String destLat, String destLng) async {
    final originLat = widget.place['lat'];
    final originLng = widget.place['lng'];
    final url =
        'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$destLat,$destLng&travelmode=driving';

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;

    return Scaffold(
      appBar: AppBar(title: Text(place["title"] ?? "Place Details")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            place["image"] != null
                ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    place["image"]!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
                : Container(height: 200, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              "📍 Address: ${place["address"]}",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              "⭐ Rating: ${place["rating"]}",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              "🏷️ Specialties: ${place["types"]}",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Text(
              "Nearby Hotels & Restaurants",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: nearbyPlaces.length,
                itemBuilder: (context, index) {
                  final place = nearbyPlaces[index];
                  return Container(
                    width: 180,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 5),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (place["image"] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Image.network(
                              place["image"]!,
                              height: 100,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                place["name"] ?? "Unknown",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                place["type"] == "restaurant"
                                    ? "Restaurant"
                                    : "Hotel",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Rating: ${place["rating"]}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap:
                                    () => _launchMapsUrl(
                                      place["lat"]!,
                                      place["lng"]!,
                                    ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.map,
                                      size: 18,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "View on Map",
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SavedTripsSection extends StatelessWidget {
  final String googleApiKey = 'AIzaSyBw1GfQx7suGPPUXdc8p5aWuw5CzdhxrP4';

  Future<String?> _fetchPhotoUrl(String location) async {
    final queryUrl =
        'https://maps.googleapis.com/maps/api/place/findplacefromtext/json'
        '?input=${Uri.encodeComponent(location)}&inputtype=textquery&fields=photos&key=$googleApiKey';

    final response = await http.get(Uri.parse(queryUrl));
    final json = jsonDecode(response.body);

    if (json['status'] == 'OK' &&
        json['candidates'] != null &&
        json['candidates'].isNotEmpty &&
        json['candidates'][0]['photos'] != null) {
      final photoRef = json['candidates'][0]['photos'][0]['photo_reference'];
      return 'https://maps.googleapis.com/maps/api/place/photo'
          '?maxwidth=400&photoreference=$photoRef&key=$googleApiKey';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('trips')
              .where('creator', isEqualTo: userId)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();

        final now = DateTime.now();

        final trips =
            snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final tripDetails =
                  data['tripDetails'] as Map<String, dynamic>? ?? {};

              final startStr = tripDetails['startDate'];
              final endStr = tripDetails['endDate'];

              if (startStr == null || endStr == null) return false;

              try {
                final start = DateTime.parse(startStr);
                final end = DateTime.parse(endStr);
                return end.isAfter(now);
              } catch (e) {
                print("Invalid date in trip: ${doc.id} — $e");
                return false;
              }
            }).toList();

        if (trips.isEmpty) return Text("No upcoming trips");

        return SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              final data = trip.data() as Map<String, dynamic>;
              final tripDetails =
                  data['tripDetails'] as Map<String, dynamic>? ?? {};

              final tripId = data['tripId'] ?? '';
              final location =
                  tripDetails['Where are you traveling to?'] ?? 'Unknown';
              final title =
                  tripDetails['Give a name to your trip'] ?? 'Unnamed Trip';

              return FutureBuilder<String?>(
                future: _fetchPhotoUrl(location),
                builder: (context, snapshot) {
                  final imageUrl = snapshot.data;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TripChatPage(tripId: tripId),
                        ),
                      );
                    },
                    child: Container(
                      width: 180,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image:
                              imageUrl != null
                                  ? NetworkImage(imageUrl)
                                  : AssetImage('assets/default_trip.jpg')
                                      as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
