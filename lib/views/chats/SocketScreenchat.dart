import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ridematch/services/API.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;

class ChatScreen extends StatefulWidget {
  final String senderId;
  final String receiverId;

  const ChatScreen({
    super.key,
    required this.senderId,
    required this.receiverId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late IO.Socket socket;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> messages = [];
  String receiverName = "Person";
  String receiverAvatar = "https://i.pravatar.cc/150?img=3";

  @override
  void initState() {
    super.initState();
    connectSocket();
    fetchMessages();
    fetchReceiverInfo();
  }

  // ---------------------- SOCKET SETUP ------------------------
  void connectSocket() {
    socket = IO.io(
      '$baseurl',
      IO.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );

    socket.connect();

    socket.onConnect((_) {
      print('🟢 Connected to Socket.IO');
      socket.emit('register', widget.senderId);
    });

    socket.on('receiveMessage', (data) {
      if (!mounted) return;

      setState(() {
        messages.add({
          'senderId': data['senderId'],
          'senderName': data['senderName'] ?? "Unknown",
          'receiverName': data['receiverName'] ?? "",
          'message': data['message'],
          'timestamp': DateTime.now().toString(),
        });
      });

      _scrollToBottom();
    });
  }

  // ---------------------- FETCH CHAT HISTORY ------------------------
  Future<void> fetchMessages() async {
    final url = Uri.parse('$baseurl/api/chat/${widget.senderId}/${widget.receiverId}');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);

      setState(() {
        messages = data.map((e) => {
          'senderId': e['senderId'],
          'senderName': e['senderName'] ?? "Unknown",
          'receiverName': e['receiverName'] ?? "",
          'message': e['message'],
          'timestamp': e['createdAt'] ?? e['timestamp'],
        }).toList();
      });

      _scrollToBottom();
    }
  }

  // ---------------------- FETCH RECEIVER INFO ------------------------
  Future<void> fetchReceiverInfo() async {
    final url = Uri.parse('$baseurl/api/users/${widget.receiverId}');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      print("🔍 USER RESPONSE: ${res.body}");

      setState(() {
        receiverName = data['name']
            ?? data['username']
            ?? data['fullName']
            ?? data['userFullName']
            ?? data['profile']?['name']
            ?? widget.receiverId;

        receiverAvatar = data['avatar']
            ?? data['profilePic']
            ?? "https://i.pravatar.cc/150?img=3";
      });

    } else {
      setState(() {
        receiverName = receiverName;
      });
    }
  }

  // ---------------------- SEND MESSAGE ------------------------
  void sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    socket.emit('sendMessage', {
      'senderId': widget.senderId,
      'receiverId': widget.receiverId,
      'message': text,
    });

    // Add locally
    setState(() {
      messages.add({
        'senderId': widget.senderId,
        'senderName': "You", // ✔ FIXED (shows your name)
        'receiverName': receiverName,
        'message': text,
        'timestamp': DateTime.now().toString(),
      });
    });

    _controller.clear();
    _scrollToBottom();
  }

  // ---------------------- SCROLL BOTTOM ------------------------
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------------------- BUILD MESSAGE BUBBLE ------------------------
  Widget buildMessage(Map<String, dynamic> msg, bool isMe) {
    final time = DateTime.parse(msg['timestamp']).toLocal();
    final formattedTime =
        "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

    final senderName = msg['senderName'] ?? (isMe ? "You" : "Unknown");

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xff113F67) : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              senderName,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isMe ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              msg['message'],
              style: GoogleFonts.dmSans(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formattedTime,
              style: GoogleFonts.dmSans(
                color: isMe ? Colors.white70 : Colors.black45,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------- UI ------------------------
  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xff113F67),
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(backgroundImage: NetworkImage(receiverAvatar)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                receiverName,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),

      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMe = msg['senderId'] == widget.senderId;
                    return buildMessage(msg, isMe);
                  },
                ),
              ),
              const SizedBox(height: 70),
            ],
          ),

          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _controller,
                      style: GoogleFonts.dmSans(fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                      ),
                      minLines: 1,
                      maxLines: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: sendMessage,
                  backgroundColor: const Color(0xff113F67),
                  child: const Icon(Icons.send, color: Colors.white),
                  elevation: 2,
                  mini: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
