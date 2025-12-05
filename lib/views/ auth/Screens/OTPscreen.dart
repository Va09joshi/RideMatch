import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OTPScreen extends StatefulWidget {
  final String phone;
  final String purpose; // optional, e.g., "reset_password" or "login"

  const OTPScreen({super.key, required this.phone, this.purpose = "login"});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<TextEditingController> _otpControllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  int _resendSeconds = 30;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendSeconds = 30;
    Future.doWhile(() async {
      if (_resendSeconds > 0) {
        await Future.delayed(const Duration(seconds: 1));
        setState(() => _resendSeconds--);
        return true;
      }
      return false;
    });
  }

  void _submitOTP() {
    String otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 6) {
      _showSnackBar("Please enter the 6-digit OTP");
      return;
    }

    setState(() => _isLoading = true);

    // TODO: Send OTP to API for verification
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _isLoading = false);

      // Navigate depending on purpose
      if (widget.purpose == "reset_password") {
        Navigator.pushReplacementNamed(context, '/resetPassword');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  void _resendOTP() {
    if (_resendSeconds > 0) return;

    setState(() => _resendSeconds = 30);
    _startResendTimer();

    // TODO: Call API to resend OTP
    _showSnackBar("OTP resent to ${widget.phone}");
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.dmSans()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildOTPField(int index) {
    return SizedBox(
      width: 45,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: "",
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
          if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _otpControllers.forEach((c) => c.dispose());
    _focusNodes.forEach((f) => f.dispose());
    super.dispose();
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
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Hero(
                    tag: "logo",
                    child: Image.asset(
                      "assets/images/logo.png",
                      height: 70,
                    ),
                  ),
                  const SizedBox(height: 35),
                  Text(
                    "Verify OTP",
                    style: GoogleFonts.dmSans(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xff0A2647),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Enter the 6-digit code sent to ${widget.phone}",
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) => _buildOTPField(index)),
                  ),
                  const SizedBox(height: 25),
                  GestureDetector(
                    onTap: _submitOTP,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff0A2647), Color(0xff1A3D64)],
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
                        "Verify OTP",
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
                        "Didn't receive OTP? ",
                        style: GoogleFonts.dmSans(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: _resendOTP,
                        child: Text(
                          _resendSeconds > 0
                              ? "Resend ($_resendSeconds s)"
                              : "Resend",
                          style: GoogleFonts.dmSans(
                            color: const Color(0xffF15A29),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
