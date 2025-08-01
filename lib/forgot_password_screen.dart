import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? message;
  bool isLoading = false;

  Future<void> resetPassword() async {
    final email = emailController.text.trim();
    FocusScope.of(context).unfocus(); // Close keyboard

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        message = "⚠️ Please enter a valid email address.";
      });
      return;
    }

    setState(() {
      isLoading = true;
      message = null;
    });

    try {
      await _auth.sendPasswordResetEmail(email: email);

      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text("Email Sent"),
              content: const Text(
                "A password reset link has been sent to your email. Please check your inbox.",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Return to login screen
                    emailController.clear();
                    setState(() => message = null);
                  },
                  child: const Text("OK"),
                ),
              ],
            ),
      );
    } catch (e) {
      setState(() {
        message = "⚠️ Error: Please check the email address.";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

 @override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return Scaffold(
    extendBodyBehindAppBar: true, // Allows gradient to show behind AppBar
    appBar: AppBar(
      title: const Text("Forgot Password"),
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    body: Container(
      decoration: BoxDecoration(
         gradient: LinearGradient(
            colors:
                isDark
                    ? [Colors.blue.shade900, Colors.black]
                    : [Colors.blue, Colors.black],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_reset, size: 80, color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                "Enter your registered email address.\nWe’ll send you a password reset link.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 30),

              // Email Input
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: "Email",
                  labelStyle: const TextStyle(color: Colors.black),
                  prefixIcon: const Icon(Icons.email, color: Colors.blue),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Message
              if (message != null)
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: message!.startsWith("⚠️")
                        ? Colors.redAccent
                        : Colors.greenAccent.shade400,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              const SizedBox(height: 20),

              // Reset Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : resetPassword,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    backgroundColor: Colors.blue.shade900,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    isLoading ? "Sending..." : "Send Reset Link",
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}