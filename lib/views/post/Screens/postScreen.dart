import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ridematch/services/API.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:ridematch/views/chats/SocketScreenchat.dart';
import 'package:ridematch/views/chats/chatHistory/chathistoryScreen.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  String? senderId;
  List<Map<String, dynamic>> myRequests = [];
  List<Map<String, dynamic>> otherRequests = [];
  bool _loading = true;

  Map<String, bool> liked = {};

  @override
  void initState() {
    super.initState();
    _loadSenderId();
  }

  Future<void> _loadSenderId() async {
    final prefs = await SharedPreferences.getInstance();
    senderId = prefs.getString('userId');
    await _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      List<Map<String, dynamic>> myReqList = [];
      List<Map<String, dynamic>> others = [];

      if (senderId != null) {
        final myResp = await http.get(
          Uri.parse('$baseurl/api/rides/requests/$senderId'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        );

        if (myResp.statusCode == 200) {
          final data = jsonDecode(myResp.body);
          myReqList = List<Map<String, dynamic>>.from(data['requests']);

          for (var req in myReqList) {
            final likedBy = req['likedBy'] ?? [];
            liked[req['_id']] = likedBy.contains(senderId);
          }
        }

        double latitude = 22.97882;
        double longitude = 76.06698;

        final nearbyResp = await http.get(
          Uri.parse(
              '$baseurl/api/rides/requests/nearby/list?longitude=$longitude&latitude=$latitude'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        );

        if (nearbyResp.statusCode == 200) {
          final data = jsonDecode(nearbyResp.body);
          others = List<Map<String, dynamic>>.from(data['requests']);

          for (var req in others) {
            final likedBy = req['likedBy'] ?? [];
            liked[req['_id']] = likedBy.contains(senderId);
          }

          others.removeWhere((req) {
            final uid = req['userId'] is Map ? req['userId']['_id'] : req['userId'];
            return uid == senderId;
          });
        }
      }

      setState(() {
        myRequests = myReqList;
        otherRequests = others;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        myRequests = [];
        otherRequests = [];
        _loading = false;
      });
    }
  }

  // 🔥 SEND LIKE/UNLIKE NOTIFICATION
  Future<void> _sendLikeNotification(String receiverId, String requestId, bool isLiked) async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final url = Uri.parse('$baseurl/api/notifications/like');

    try {
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "senderId": senderId,
          "receiverId": receiverId,
          "requestId": requestId,
          "type": isLiked ? "like" : "unlike" // <-- Correctly notify like/unlike
        }),
      );

      print("LIKE NOTIFICATION SENT → ${res.body}");
    } catch (e) {
      print("Error sending like notification: $e");
      // If failed, revert the UI toggle
      setState(() {
        liked[requestId] = !isLiked;
      });
    }
  }

  String _getUserProfileImage(dynamic user) {
    if (user == null) return 'https://www.pngall.com/wp-content/uploads/5/User-Profile-PNG.png';
    if (user is Map) {
      if (user.containsKey('profileImage') && user['profileImage'] != null && user['profileImage'].toString().isNotEmpty) {
        return user['profileImage'];
      } else if (user.containsKey('avatar') && user['avatar'] != null && user['avatar'].toString().isNotEmpty) {
        return user['avatar'];
      }
    }
    return 'https://www.pngall.com/wp-content/uploads/5/User-Profile-PNG.png';
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final user = request['userId'];
    final userId = user is Map ? user['_id'] : user;
    final userName = user is Map ? user['name'] : 'Unknown';
    final userImage = _getUserProfileImage(user);

    final requestId = request['_id'];
    liked.putIfAbsent(requestId, () => false);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: userImage.isNotEmpty
                    ? NetworkImage(userImage)
                    : const NetworkImage("https://i.pravatar.cc/150?img=10"),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userName,
                      style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700, fontSize: 17)),
                  Text(
                    "${request['date'] ?? ''} • ${request['time'] ?? ''}",
                    style:
                    GoogleFonts.dmSans(fontSize: 13, color: Colors.black54),
                  )
                ],
              ),
              const Spacer(),

              // ❤️ LIKE BUTTON → Sends Notification
              GestureDetector(
                onTap: () async {
                  bool newState = !liked[requestId]!;
                  setState(() => liked[requestId] = newState);

                  // Send correct like/unlike notification
                  await _sendLikeNotification(userId, requestId, newState);
                },
                child: Icon(
                  liked[requestId]!
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: liked[requestId]! ? Colors.red : Colors.grey.shade600,
                  size: 28,
                ),
              )
            ],
          ),

          const SizedBox(height: 16),
          _locationBox(request),
          const SizedBox(height: 10),

          Text(request['note'] ?? '',
              style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black87)),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff113F67),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              ),
              onPressed: () {
                if (senderId == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ChatScreen(senderId: senderId!, receiverId: userId)),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              label: Text("Chat",
                  style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  Widget _locationBox(Map<String, dynamic> req) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff113F67).withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xff113F67)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(req["from"] ?? "",
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
              )
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.flag, color: Color(0xff113F67)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(req["to"] ?? "",
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (myRequests.isNotEmpty)
          Text("Your Requests",
              style: GoogleFonts.dmSans(
                  fontSize: 18, fontWeight: FontWeight.w700)),
        ...myRequests.map(_buildMyRequestCard),
        const SizedBox(height: 10),
        Text("Nearby Requests",
            style: GoogleFonts.dmSans(
                fontSize: 18, fontWeight: FontWeight.w700)),
        ...otherRequests.map(_buildRequestCard),
      ],
    );
  }

  Widget _buildMyRequestCard(Map<String, dynamic> req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade700],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "${req['from']} → ${req['to']}  •  ${req['date']}",
              style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ),
          Text("Your Post",
              style:
              GoogleFonts.dmSans(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xff113F67),
        title: Text("Posts",
            style: GoogleFonts.dmSans(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
          onRefresh: _fetchRequests,
          child: _buildRequestList()),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (senderId == null) return;
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    ChatHistoryScreen(userId: senderId!)),
          );
        },
        backgroundColor: const Color(0xff113F67),
        child: const Icon(Icons.chat_rounded, color: Colors.white),
      ),
    );
  }
}
