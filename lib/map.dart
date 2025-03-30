import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

class MapPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PlacesSearchScreen(),
    );
  }
}

class PlacesSearchScreen extends StatefulWidget {
  @override
  _PlacesSearchScreenState createState() => _PlacesSearchScreenState();
}

class _PlacesSearchScreenState extends State<PlacesSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  Set<Marker> _markers = {};
  static const String apiKey =
      "AIzaSyCOr_KyM48c7Uu_2Pk21yXdItisrZbCR10"; // Store securely

  List<dynamic> visitedPlaces = [];
  List<dynamic> upcomingPlaces = [];

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    _loadPlacesData(); // Load visited and upcoming places
  }

  // Load the map style
  Future<void> _loadMapStyle() async {
    String style = await rootBundle.loadString('assets/map_style.json');
    _mapController?.setMapStyle(style);
  }

  // Load visited and upcoming places from JSON
  Future<void> _loadPlacesData() async {
    try {
      String data = await rootBundle.loadString('assets/places_data.json');
      final jsonData = json.decode(data);
      setState(() {
        visitedPlaces = jsonData['visited'];
        upcomingPlaces = jsonData['upcoming'];
        _addMarkersFromPlacesData();
      });
    } catch (e) {
      print("Error loading places data: $e");
    }
  }

  // Add markers for visited and upcoming places
  void _addMarkersFromPlacesData() {
    Set<Marker> tempMarkers = {};

    // Add visited places as green markers
    for (var place in visitedPlaces) {
      tempMarkers.add(
        Marker(
          markerId: MarkerId(place['name']),
          position: LatLng(place['lat'], place['lng']),
          infoWindow: InfoWindow(title: place['name']),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    // Add upcoming places as red markers
    for (var place in upcomingPlaces) {
      tempMarkers.add(
        Marker(
          markerId: MarkerId(place['name']),
          position: LatLng(place['lat'], place['lng']),
          infoWindow: InfoWindow(title: place['name']),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    setState(() {
      _markers = tempMarkers;
    });
  }

  Future<void> _searchLocation() async {
    String query = _searchController.text;
    if (query.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        Location loc = locations.first;
        setState(() {
          _selectedLocation = LatLng(loc.latitude, loc.longitude);
          _markers.clear();
          _markers.add(
            Marker(
              markerId: MarkerId("searched_location"),
              position: _selectedLocation!,
              infoWindow: InfoWindow(title: "Searched Location"),
            ),
          );
        });
        _mapController
            ?.animateCamera(CameraUpdate.newLatLngZoom(_selectedLocation!, 14));
        _fetchNearbyPlaces(loc.latitude, loc.longitude);
      }
    } catch (e) {
      print("Error fetching location: $e");
    }
  }

  void _showPlaceDetails(dynamic place) async {
    String imageUrl = '';

    if (place.containsKey('photos') && place['photos'].isNotEmpty) {
      String photoReference = place['photos'][0]['photo_reference'];
      imageUrl = await _getPlaceImage(photoReference);
    }

    if (!mounted) return; // Ensure the widget is still active

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                place['name'],
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text("⭐ Rating: ${place['rating'] ?? 'N/A'}"),
              if (place.containsKey('vicinity'))
                Text("📍 Location: ${place['vicinity']}"),
              SizedBox(height: 10),
              imageUrl.isNotEmpty
                  ? Image.network(imageUrl, height: 200, fit: BoxFit.cover)
                  : Text("No image available"),
            ],
          ),
        );
      },
    );
  }

  Future<void> _fetchNearbyPlaces(double lat, double lng) async {
    String url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?"
        "location=$lat,$lng&radius=10000&type=tourist_attraction&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> places = data['results'];

        List<dynamic> topPlaces = places
            .where((place) =>
                place.containsKey('rating') && place['rating'] >= 4.0)
            .toList();
        topPlaces.sort((a, b) => b['rating'].compareTo(a['rating']));

        setState(() {
          _markers.clear();
          _markers.addAll(topPlaces.map((place) {
            String photoReference =
                place['photos'] != null && place['photos'].isNotEmpty
                    ? place['photos'][0]['photo_reference']
                    : '';

            return Marker(
              markerId: MarkerId(place['name']),
              position: LatLng(
                place['geometry']['location']['lat'],
                place['geometry']['location']['lng'],
              ),
              infoWindow: InfoWindow(
                title: place['name'],
                snippet: "Rating: ${place['rating'] ?? 'N/A'}",
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue),
              onTap: () => _showPlaceDetails(place), // ✅ Ensure this triggers
            );
          }));
        });
      } else {
        print("Failed to fetch places: ${response.body}");
      }
    } catch (e) {
      print("Error fetching nearby places: $e");
    }
  }

  Future<String> _getPlaceImage(String photoReference) async {
    if (photoReference.isEmpty) return ''; // No photo

    return "https://maps.googleapis.com/maps/api/place/photo"
        "?maxwidth=400"
        "&photoreference=$photoReference"
        "&key=$apiKey";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Travel Guide")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Enter city, area, or tourist spot",
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _searchLocation,
                ),
              ),
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(20.5937, 78.9629),
                zoom: 5,
              ),
              markers: _markers,
              onMapCreated: (controller) {
                _mapController = controller;
                _loadMapStyle();
              },
            ),
          ),
        ],
      ),
    );
  }
}
