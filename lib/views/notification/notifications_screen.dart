import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List notifications = [];
  bool loading = true;     // ✔ correct variable
  String? userId;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId');
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => loading = true);   // ✔ FIXED

    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? userId = prefs.getString('userId');

    final url = Uri.parse("http://192.168.29.206:5000/api/notifications/$userId");

    try {
      final res = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token'
        },
      );

      print("NOTIFICATION RESPONSE → ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        // FIX: auto-detect key
        List<dynamic> list =
            data['notifications'] ??
                data['notification'] ??
                data['data'] ??
                [];

        setState(() {
          notifications = List<Map<String, dynamic>>.from(list);
          loading = false;     // ✔ FIXED
        });
      } else {
        setState(() {
          notifications = [];
          loading = false;     // ✔ FIXED
        });
      }
    } catch (e) {
      print("ERROR fetching notifications → $e");
      setState(() {
        notifications = [];
        loading = false;       // ✔ FIXED
      });
    }
  }

  String timeAgo(String isoString) {
    final time = DateTime.parse(isoString);
    final diff = DateTime.now().difference(time);

    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
    if (diff.inHours < 24) return "${diff.inHours} hrs ago";
    return "${diff.inDays} days ago";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Notifications",
          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
      ),
      body: loading                                   // ✔ FIXED
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: notifications.isEmpty
            ? Center(
          child: Text(
            "No Notifications",
            style: GoogleFonts.dmSans(fontSize: 16),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final item = notifications[index];
            final sender = item["senderId"];

            return _buildNotificationItem(
              image: sender["profileImage"] ?? "",
              name: sender["name"] ?? "Someone",
              type: item["type"],
              time: timeAgo(item["createdAt"]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required String image,
    required String name,
    required String type,
    required String time,
  }) {
    String message = "";

    if (type == "like") {
      message = "$name liked your request post ❤️";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: image.isNotEmpty
                ? NetworkImage(image)
                : const NetworkImage(
                "https://i.imgur.com/DefaultUser.png"),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "New Notification",
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.dmSans(
                      fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
