import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ridematch/views/%20auth/Screens/OTPscreen.dart';

class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  void sendOTP() {
    String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnackBar("Please enter your phone number");
      return;
    }

    setState(() => _isLoading = true);

    // TODO: Call API to send OTP for password reset
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _isLoading = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OTPScreen(phone: phone)
        ),
      );
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.dmSans()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildPhoneField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _phoneController.text.isNotEmpty
              ? const Color(0xff0A2647).withOpacity(0.7)
              : Colors.grey.shade300,
          width: 1.2,
        ),
        boxShadow: _phoneController.text.isNotEmpty
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
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        style: GoogleFonts.dmSans(color: Colors.black87),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey),
          hintText: "Enter phone number",
          hintStyle: GoogleFonts.dmSans(color: Colors.grey[500]),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(seconds: 2),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Color(0xffF6F7F7)],
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Hero(
                      tag: "logo",
                      child: Image.asset(
                        "assets/images/logo.png", // Replace with your logo
                        height: 70,
                      ),
                    ),
                    const SizedBox(height: 35),
                    Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
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
                            "Forget Password",
                            style: GoogleFonts.dmSans(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xff0A2647),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Enter your phone number to reset your password",
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          _buildPhoneField(),
                          const SizedBox(height: 25),
                          GestureDetector(
                            onTap: sendOTP,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xff0A2647),
                                    Color(0xff1A3D64)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xff0A2647)
                                        .withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                  color: Colors.white)
                                  : Text(
                                "Send OTP",
                                style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Image.asset(
                      "assets/images/bgcar.png", // Replace with your background image
                      fit: BoxFit.contain,
                      height: 300,
                      width: double.infinity,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
