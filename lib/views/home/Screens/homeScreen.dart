import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:ridematch/services/API.dart';
import 'package:ridematch/views/home/Screens/bottomsheets/CreateRequest.dart';
import 'package:ridematch/views/home/Screens/bottomsheets/CreateRide.dart';
import 'package:ridematch/views/notification/notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:badges/badges.dart' as badges;


class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? bookedRide;

  const HomeScreen({super.key, this.bookedRide});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? mapController;
  LatLng? _currentPosition;
  Set<Marker> _markers = {};
  bool isLoading = false;
  BitmapDescriptor? rideMarkerIcon;
  bool hasNewNotification = false;


  List<dynamic> ridePosts = [];
  String? userName;
  String? fullAddress;
  String? currentUserId;

  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialize();
    fromController.addListener(_filterRides);
    toController.addListener(_filterRides);
    _loadMarkerIcon();
  }

  // Load custom marker
  Future<void> _loadMarkerIcon() async {
    rideMarkerIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/ride_marker.png',
    );
  }

  // Initialization
  Future<void> _initialize() async {
    await _getUserLocation();
    await _loadUserData();
    await fetchUserData();
    await fetchRides();

    if (widget.bookedRide != null) {
      _addBookedRideMarker(widget.bookedRide!);
    }
  }

  // Get current user location
  Future<void> _getUserLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

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

  Future<void> checkNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? userId = prefs.getString('userId');

    if (userId == null) return;

    final res = await http.get(
      Uri.parse("$baseurl/api/notifications/$userId"),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = List<Map<String, dynamic>>.from(
          data['notifications'] ?? data['notification'] ?? data['data'] ?? []);
      if (list.any((item) => item['read'] == false)) {
        setState(() {
          hasNewNotification = true;
        });
      }
    }
  }

  // Load user data from SharedPreferences
  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('username') ?? "User";
      currentUserId = prefs.getString('userId');
    });
  }

  // Fetch profile
  Future<void> fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    if (token == null) return;

    try {
      final res = await http.get(
        Uri.parse('$baseurl/api/user/profile'),
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

  // Fetch rides
  Future<void> fetchRides() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseurl/api/rides'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          ridePosts = data['rides'];
          _addRideMarkers();
        });
      }
    } catch (e) {
      print("Error fetching rides: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Add all ride markers
  void _addRideMarkers() {
    _markers.clear();

    for (var ride in ridePosts) {
      final driver = ride['driverId'];
      final driverId = driver is String ? driver : driver['_id'];

      if (driverId == currentUserId) continue;

      if (ride['fromLat'] != null && ride['fromLong'] != null) {
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
            icon: rideMarkerIcon ?? BitmapDescriptor.defaultMarker,
          ),
        );
      }
    }

    setState(() {});
    _zoomToFitMarkers();
  }

  // Filter rides by From/To
  void _filterRides() {
    String from = fromController.text.toLowerCase();
    String to = toController.text.toLowerCase();

    _markers.clear();

    for (var ride in ridePosts) {
      final driver = ride['driverId'];
      final driverId = driver is String ? driver : driver['_id'];

      if (driverId == currentUserId) continue;

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

  // Zoom map to fit all markers
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

  // Add booked ride markers
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

      _markers.add(
        Marker(
          markerId: const MarkerId('booked_pickup'),
          position: pickup,
          infoWindow: const InfoWindow(title: "Your Pickup"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('booked_drop'),
          position: drop,
          infoWindow: const InfoWindow(title: "Your Drop"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );

      Future.delayed(const Duration(milliseconds: 300), _zoomToFitMarkers);
    }
  }

  // Show ride detail bottom sheet
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
                style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Driver: ${ride["driverId"]["name"] ?? 'N/A'}",
                style: GoogleFonts.dmSans(fontSize: 16)),
            Text("Amount: Rs ${ride['amount']}", style: GoogleFonts.dmSans(fontSize: 16)),
            Text("Seats: ${ride['seats']}", style: GoogleFonts.dmSans(fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.group_add),
                  label: const Text("Join Ride"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text("Chat"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text("Propose"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Quick Actions bottom sheet
  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white54,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Wrap(
          runSpacing: 6,
          children: [
            Center(
              child: Container(
                height: 5,
                width: 60,
                decoration: BoxDecoration(
                  color: Color(0xff113F67),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                "Quick Actions",
                style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(thickness: 1, height: 20),
            _buildActionTile(
              icon: Icons.directions_car,
              title: "Create a Ride",
              iconBgColor: Colors.blue.shade50,
              iconColor: Colors.blue.shade700,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateRideScreen()),
              ),
            ),
            _buildActionTile(
              icon: Icons.add_location_alt,
              title: "Create a Location Request",
              iconBgColor: Colors.green.shade50,
              iconColor: Colors.green.shade700,
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
              title: "Nearby Matches",
              iconBgColor: Colors.orange.shade50,
              iconColor: Colors.orange.shade700,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(14),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.dmSans(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey[400]),
          ],
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
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(fullAddress ?? "Fetching location...",
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w400)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: badges.Badge(
              showBadge: hasNewNotification, // boolean you will track
              badgeStyle: const badges.BadgeStyle(
                badgeColor: Colors.red,
                elevation: 0,
              ),
              badgeContent: const SizedBox.shrink(), // small dot
              child: const Icon(Icons.notifications, color: Colors.white),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              ).then((_) {
                // reset the badge after opening notifications
                setState(() {
                  hasNewNotification = false;
                });
              });
            },
          )
        ],
      ),
      body: Stack(
        children: [
          _currentPosition == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
            onMapCreated: (controller) => mapController = controller,
            initialCameraPosition: CameraPosition(target: _currentPosition!, zoom: 14.5),
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
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 3))],
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
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
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
                  IconButton(icon: const Icon(Icons.filter_alt_outlined, color: Colors.blueAccent), onPressed: _filterRides),
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
          label: Text("Quick Actions", style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w500)),
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          elevation: 8,
        ),
      ),
    );
  }
}
