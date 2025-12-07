import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ridematch/services/API.dart';
import 'package:ridematch/views/about/about_app.dart';
import 'package:ridematch/views/notification/notifications_screen.dart';
import 'package:ridematch/views/profile/cards/help/HelpCenter.dart';
import 'package:ridematch/views/profile/cards/language/language_pref.dart';
import 'package:ridematch/views/profile/cards/myrides.dart';
import 'package:ridematch/views/profile/cards/verfied%20document/verfiedDoc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  File? _profileImage;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  // Fetch user profile data
  Future<void> fetchUserData() async {
    setState(() => isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    if (token == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse("$baseurl/api/auth/me"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          userData = data['user'] ?? data;
          _nameController.text = userData?['name'] ?? '';
          _emailController.text = userData?['email'] ?? '';
          _phoneController.text = userData?['phone'] ?? '';
          _profileImage = null; // Use uploaded image if available
          isLoading = false;
        });
      } else if (response.statusCode == 401) {
        logout();
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Error loading profile: $e");
      setState(() => isLoading = false);
    }
  }

  // Logout function
  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  // Pick image from gallery
  Future<void> pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
      await uploadProfileImage(_profileImage!);
    }
  }

  // Upload image to server

  Future<void> uploadProfileImage(File image) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) return;

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseurl/api/profile/upload-profile'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      request.files.add(await http.MultipartFile.fromPath('profile', image.path));

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      debugPrint('Upload response: $respStr');

      if (response.statusCode == 200) {
        _snack("Profile picture updated successfully");
        await fetchUserData(); // refresh profile
      } else {
        _snack("Upload failed: ${response.statusCode}", error: true);
      }
    } catch (e) {
      debugPrint("Upload error: $e");
      _snack("Upload failed: $e", error: true);
    }
  }




  // Update profile info
  Future<void> updateProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    if (token == null) return;

    try {
      final response = await http.put(
        Uri.parse("$baseurl/api/auth/update-profile"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          if (_passwordController.text.isNotEmpty)
            'password': _passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        _snack("Profile updated successfully");
        await fetchUserData();
      } else {
        _snack("Failed to update profile", error: true);
      }
    } catch (e) {
      debugPrint("❌ Update error: $e");
      _snack("Update failed", error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F7FC),
      appBar: AppBar(
        backgroundColor: const Color(0xff0B2847),
        title: Text(
          "Profile",
          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            _header(),
            _profileForm(),
            _sectionWithOptions(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final String? profileUrl = userData?['profileImage'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff113F67), Color(0xff0B2847)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: pickImage,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.white,
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!)
                      : (userData?['profileImage'] != null && userData!['profileImage'].isNotEmpty
                      ? NetworkImage(userData!['profileImage'])
                      : AssetImage('assets/images/default_avatar.png') as ImageProvider),
                ),


                const Positioned(
                  right: 4,
                  bottom: 4,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.camera_alt, size: 18, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            userData?['name'] ?? "User",
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          Text(
            userData?['email'] ?? "",
            style: GoogleFonts.dmSans(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          _sectionTitle("Account Information"),
          _input("Full Name", _nameController),
          _input("Email", _emailController),
          _input("Phone", _phoneController),
          _input("Password", _passwordController, obscure: true),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: updateProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff113F67),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              "Update Profile",
              style: GoogleFonts.dmSans(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionWithOptions() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: _sectionTitle("Your Activities"),
        ),
        _optionCard(Icons.document_scanner, "Verified Document", () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => VerifiedDoc()));
        }),
        _optionCard(Icons.directions_car_rounded, "My Rides", () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => MyRidesScreen()));
        }),
        _optionCard(Icons.wallet_rounded, "Payment Methods", () {
          Navigator.pushNamed(context, '/payments');
        }),
        _optionCard(Icons.support_agent_rounded, "Help Center", () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => HelpCenterPage()));
        }),
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: _sectionTitle("Settings"),
        ),
        _optionCard(Icons.lock_rounded, "Privacy & Security", () {
          Navigator.pushNamed(context, '/privacy');
        }),
        _optionCard(Icons.notifications, "Notifications", () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationScreen()));
        }),
        _optionCard(Icons.language, "Language Preferences", () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => LanguageScreen()));
        }),
        _optionCard(Icons.info_outline, "About App", () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => AboutAppScreen()));
        }),
        const SizedBox(height: 25),
        _logoutButton(),
      ],
    );
  }

  Widget _input(String label, TextEditingController controller, {bool obscure = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.dmSans(color: Colors.black54, fontSize: 14),
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xff113F67)),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 6),
        child: Text(
          title,
          style: GoogleFonts.dmSans(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
    );
  }

  Widget _optionCard(IconData icon, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xff113F67), size: 26),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.dmSans(
                    color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  Widget _logoutButton() {
    return GestureDetector(
      onTap: logout,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            "Log Out",
            style: GoogleFonts.dmSans(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
