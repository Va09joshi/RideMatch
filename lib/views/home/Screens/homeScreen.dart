import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:ridematch/views/home/Screens/bottomsheets/CreateRequest.dart';
import 'package:ridematch/views/home/Screens/bottomsheets/CreateRide.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? bookedRide; // Add this

  const HomeScreen({super.key, this.bookedRide});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? mapController;
  LatLng? _currentPosition;
  Set<Marker> _markers = {};
  bool isLoading = false;

  List<dynamic> ridePosts = [];
  String? userName;
  String? fullAddress;

  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialize();
    fromController.addListener(_filterRides);
    toController.addListener(_filterRides);
  }

  Future<void> _initialize() async {
    await _getUserLocation();
    await _loadUserData();
    await fetchUserData();
    await fetchRides();

    if (widget.bookedRide != null) {
      _addBookedRideMarker(widget.bookedRide!);
    }
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    List<Placemark> placemarks =
    await placemarkFromCoordinates(position.latitude, position.longitude);

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      fullAddress =
      "${placemarks.first.locality ?? ''}, ${placemarks.first.administrativeArea ?? ''}";
    });
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('username') ?? "User";
    });
  }

  Future<void> fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    if (token == null) return;

    try {
      final res = await http.get(
        Uri.parse('http://192.168.29.206:5000/api/user/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final fetchedName = data['user']?['name'] ?? "User";
        await prefs.setString('username', fetchedName);
        setState(() => userName = fetchedName);
      }
    } catch (e) {
      print("❌ Error fetching user data: $e");
    }
  }

  Future<void> fetchRides() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('http://192.168.29.206:5000/api/rides'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          ridePosts = data['rides'];
          _addRideMarkers(); // Add markers for all rides
        });
      }
    } catch (e) {
      print("Error fetching rides: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }



  // Show all rides as markers
  void _addRideMarkers() {
    _markers.clear();

    for (var ride in ridePosts) {
      if (ride['fromLat'] != null && ride['fromLong'] != null) {
        final marker = Marker(
          markerId: MarkerId(ride['_id']),
          position: LatLng(
            double.parse(ride['fromLat'].toString()),
            double.parse(ride['fromLong'].toString()),
          ),
          infoWindow: InfoWindow(
            title: "${ride['from']} → ${ride['to']}",
            snippet: "Rs ${ride['amount']}",
            onTap: () => _showRideDetail(ride),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        );
        _markers.add(marker);
      }
    }

    setState(() {});
    _zoomToFitMarkers();
  }

  // Filter rides using From/To input
  void _filterRides() {
    String from = fromController.text.toLowerCase();
    String to = toController.text.toLowerCase();

    _markers.clear();

    for (var ride in ridePosts) {
      String rideFrom = (ride['from'] ?? '').toLowerCase();
      String rideTo = (ride['to'] ?? '').toLowerCase();

      if ((from.isEmpty || rideFrom.contains(from)) &&
          (to.isEmpty || rideTo.contains(to)) &&
          ride['fromLat'] != null &&
          ride['fromLong'] != null) {
        _markers.add(
          Marker(
            markerId: MarkerId(ride['_id']),
            position: LatLng(
              double.parse(ride['fromLat'].toString()),
              double.parse(ride['fromLong'].toString()),
            ),
            infoWindow: InfoWindow(
              title: "${ride['from']} → ${ride['to']}",
              snippet: "Rs ${ride['amount']}",
              onTap: () => _showRideDetail(ride),
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        );
      }
    }

    setState(() {});
    _zoomToFitMarkers();
  }

  // Zoom map to include all markers
  void _zoomToFitMarkers() {
    if (_markers.isEmpty || mapController == null) return;

    double minLat = _markers.first.position.latitude;
    double maxLat = _markers.first.position.latitude;
    double minLng = _markers.first.position.longitude;
    double maxLng = _markers.first.position.longitude;

    for (var marker in _markers) {
      minLat = marker.position.latitude < minLat ? marker.position.latitude : minLat;
      maxLat = marker.position.latitude > maxLat ? marker.position.latitude : maxLat;
      minLng = marker.position.longitude < minLng ? marker.position.longitude : minLng;
      maxLng = marker.position.longitude > maxLng ? marker.position.longitude : maxLng;
    }

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  void _addBookedRideMarker(Map<String, dynamic> ride) {
    if (ride['pickupLocation'] != null && ride['dropLocation'] != null) {
      final pickup = LatLng(
        ride['pickupLocation']['lat'],
        ride['pickupLocation']['lng'],
      );
      final drop = LatLng(
        ride['dropLocation']['lat'],
        ride['dropLocation']['lng'],
      );

      // Add pickup marker
      _markers.add(
        Marker(
          markerId: const MarkerId('booked_pickup'),
          position: pickup,
          infoWindow: const InfoWindow(title: "Your Pickup"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );

      // Add drop marker
      _markers.add(
        Marker(
          markerId: const MarkerId('booked_drop'),
          position: drop,
          infoWindow: const InfoWindow(title: "Your Drop"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );

      // Optional: Zoom to fit booked ride
      Future.delayed(const Duration(milliseconds: 300), _zoomToFitMarkers);
    }
  }


  void _showRideDetail(dynamic ride) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${ride['from']} → ${ride['to']}",
                style:
                GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Driver: ${ride["driverId"]["name"] ?? 'N/A'}",
                style: GoogleFonts.dmSans(fontSize: 16)),
            Text("Amount: Rs ${ride['amount']}",
                style: GoogleFonts.dmSans(fontSize: 16)),
            Text("Seats: ${ride['seats']}", style: GoogleFonts.dmSans(fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.group_add),
                  label: const Text("Join Ride"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text("Chat"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text("Propose"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          runSpacing: 20,
          children: [
            Center(
              child: Container(
                height: 5,
                width: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                "Quick Actions",
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Divider(thickness: 1, height: 10),
            _buildActionTile(
              icon: Icons.directions_car,
              iconColor: Colors.blue,
              iconBg: const Color(0xFFCCE5FF),
              title: "Create a Ride",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateRideScreen()),
              ),
            ),
            _buildActionTile(
              icon: Icons.add_location_alt,
              iconColor: Colors.green,
              iconBg: const Color(0xFFDFFFD6),
              title: "Create a Location Request",
              onTap: () {
                Navigator.pop(context);
                if (ridePosts.isNotEmpty) {
                  openCreateLocationRequest(ridePosts[0]['_id']);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No rides available to request.")),
                  );
                }
              },
            ),
            _buildActionTile(
              icon: Icons.people_alt,
              iconColor: Colors.orange,
              iconBg: const Color(0xFFFFE6CC),
              title: "Nearby Matches",
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black45.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: iconBg,
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w500, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void openCreateLocationRequest(String rideId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateLocationRequestScreen(rideId: rideId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xff113F67),
        toolbarHeight: 75,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Hey ${userName ?? 'User'} 👋",
                style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(fullAddress ?? "Fetching location...",
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w400)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications, color: Colors.white), onPressed: () {})
        ],
      ),
      body: Stack(
        children: [
          _currentPosition == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
            onMapCreated: (controller) => mapController = controller,
            initialCameraPosition:
            CameraPosition(target: _currentPosition!, zoom: 14.5),
            myLocationEnabled: true,
            markers: _markers,
          ),
          Positioned(
            top: 16,
            left: 12,
            right: 12,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: const Offset(0, 3))
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fromController,
                      decoration: InputDecoration(
                        hintText: "From...",
                        border: InputBorder.none,
                        hintStyle: GoogleFonts.dmSans(color: Colors.grey),
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: toController,
                      decoration: InputDecoration(
                        hintText: "To...",
                        border: InputBorder.none,
                        hintStyle: GoogleFonts.dmSans(color: Colors.grey),
                      ),
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.filter_alt_outlined,
                          color: Colors.blueAccent),
                      onPressed: _filterRides),
                ],
              ),
            ),
          ),


        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton.extended(
          onPressed: _showQuickActions,
          backgroundColor: const Color(0xff113F67),
          label: Text("Quick Actions",
              style: GoogleFonts.dmSans(
                  color: Colors.white, fontWeight: FontWeight.w500)),
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          elevation: 8,
        ),
      ),
    );
  }
}
