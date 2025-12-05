import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:ridematch/services/API.dart';
import 'package:ridematch/utils/images.dart';
import 'dart:convert';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // final String apiUrl = "http://10.0.2.2:5000/api/auth/register";
  final String apiUrl = "$baseurl/api/auth/register";  // for signup

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();

  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> signUpUser() async {
    String username = _usernameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar("Please fill all fields");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": username,
          "email": email,
          "password": password,
        }),
      );

      final data = jsonDecode(response.body);

      if  (response.statusCode == 200 &&
      (data['success'] == true || data['status'] == true || data['message'].toString().toLowerCase().contains('success'))) {
        _showSnackBar("Account Created Successfully!");
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        _showSnackBar(data['message'] ?? "Signup Failed");
      }
    } catch (e) {
      print("Error: $e");
      _showSnackBar("Error connecting to server");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.dmSans()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🌈 Animated gradient background
          AnimatedContainer(
            duration: const Duration(seconds: 2),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white,Color(0xffF6F7F7),],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 35),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Hero(
                          tag: "logo",
                          child: Image.asset(
                            Images.logo,
                            height: 70,
                          ),
                        ),
                        const SizedBox(height: 35),

                        // 💎 Frosted glass signup card
                        Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12.withOpacity(0.3),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                "Create Account",
                                style: GoogleFonts.dmSans(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xff0A2647),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "Join RideMatch and start your journey today",
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 30),

                              _buildTextField(
                                controller: _usernameController,
                                hintText: "Username",
                                icon: Icons.person_outline,
                              ),
                              const SizedBox(height: 18),

                              _buildTextField(
                                controller: _emailController,
                                hintText: "Email",
                                icon: Icons.email_outlined,
                              ),
                              const SizedBox(height: 18),

                              _buildTextField(
                                controller: _passwordController,
                                hintText: "Password",
                                icon: Icons.lock_outline,
                                obscureText: !_passwordVisible,
                                suffix: IconButton(
                                  icon: Icon(
                                    _passwordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _passwordVisible = !_passwordVisible;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(height: 25),

                              // 🌟 Animated Sign Up Button
                              GestureDetector(
                                onTapDown: (_) => setState(() => _isLoading = true),
                                onTapUp: (_) {
                                  setState(() => _isLoading = false);
                                  signUpUser();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xff1A2A4F), Color(0xff1A3D64)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xff0A2647).withOpacity(0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: _isLoading
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : Text(
                                    "Sign Up",
                                    style: GoogleFonts.dmSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Already have an account? ",
                                    style: GoogleFonts.dmSans(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                  FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: SlideTransition(
                                      position: _slideAnimation,
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.pop(context);
                                        },
                                        child: Text(
                                          "Sign In",
                                          style: GoogleFonts.dmSans(
                                            color: const Color(0xffF15A29),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        Image.asset(
                          Images.bgcar,
                          fit: BoxFit.contain,
                          height: 300,
                          width: double.infinity,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return Focus(
      onFocusChange: (hasFocus) => setState(() {}),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: controller.text.isNotEmpty
                ? const Color(0xff0A2647).withOpacity(0.7)
                : Colors.grey.shade300,
            width: 1.2,
          ),
          boxShadow: controller.text.isNotEmpty
              ? [
            BoxShadow(
              color: const Color(0xff0A2647).withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ]
              : [],
        ),
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          style: GoogleFonts.dmSans(color: Colors.black87),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey[600]),
            suffixIcon: suffix,
            hintText: hintText,
            hintStyle: GoogleFonts.dmSans(color: Colors.grey[500]),
            border: InputBorder.none,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          ),
        ),
      ),
    );
  }
}
