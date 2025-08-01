// import 'package:attendance_app_2/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String username = _usernameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();

    if (password != confirmPassword) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords do not match"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      List<String> signInMethods = await _auth.fetchSignInMethodsForEmail(
        email,
      );
      if (signInMethods.isNotEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Email is already registered! Please login."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      User? user = userCredential.user;

      if (user != null) {
        FirebaseFirestore firestore = FirebaseFirestore.instance;
        await firestore.collection('users').doc(user.uid).set({
          'username': username,
          'email': email,
          'password': password,
          'phone' : '',
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() => _isLoading = false);

        // Replace all routes and go to home screen
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home', // Make sure '/home' corresponds to your actual route name for the home screen
          (route) =>
              false, // This will remove all previous routes (signup, login)
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      String errorMessage = "An error occurred";
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = "Email is already registered!";
            break;
          case 'weak-password':
            errorMessage = "Password should be at least 6 characters.";
            break;
          case 'invalid-email':
            errorMessage = "Invalid email address.";
            break;
          default:
            errorMessage = e.message ?? "Error occurred!";
            break;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }
  }
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  final textColor = isDark ? Colors.white : Colors.black87;
  final inputFillColor = isDark ? Colors.grey[900] : Colors.white;
  final iconColor = isDark ? Colors.blue.shade200 : Colors.blue.shade700;

  return Scaffold(
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: textColor),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: Container(
      width: double.infinity,
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
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    Icon(Icons.person_add, size: 80, color: textColor),
                    const SizedBox(height: 20),
                    Text(
                      "Create Your Account",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Username Field
                    buildTextField(
                      _usernameController,
                      "User Name",
                      Icons.person,
                      inputFillColor,
                      iconColor,
                      textColor,
                    ),
                    const SizedBox(height: 16),

                    // Email Field
                    buildTextField(
                      _emailController,
                      "Email Address",
                      Icons.mail,
                      inputFillColor,
                      iconColor,
                      textColor,
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    buildPasswordField(
                      _passwordController,
                      "Create Password",
                      Icons.lock,
                      true,
                      inputFillColor,
                      iconColor,
                      textColor,
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password Field
                    buildPasswordField(
                      _confirmPasswordController,
                      "Confirm Password",
                      Icons.lock,
                      false,
                      inputFillColor,
                      iconColor,
                      textColor,
                    ),
                    const SizedBox(height: 28),

                    // Sign Up Button
                    _isLoading
                        ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(textColor),
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: signUp,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.blue.shade800,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                "Sign Up",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}


// Updated input field builders with color params

Widget buildTextField(
  TextEditingController controller,
  String hintText,
  IconData icon,
  Color? fillColor,
  Color iconColor,
  Color textColor,
) {
  return Container(
    decoration: BoxDecoration(
      color: fillColor,
      borderRadius: BorderRadius.circular(10),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
    ),
    child: TextFormField(
      controller: controller,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
        prefixIcon: Icon(icon, color: iconColor),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      ),
      validator: (value) => value!.isEmpty ? "Please enter $hintText" : null,
    ),
  );
}

Widget buildPasswordField(
  TextEditingController controller,
  String hintText,
  IconData icon,
  bool isMainPassword,
  Color? fillColor,
  Color iconColor,
  Color textColor,
) {
  return Container(
    decoration: BoxDecoration(
      color: fillColor,
      borderRadius: BorderRadius.circular(10),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
    ),
    child: TextFormField(
      controller: controller,
      obscureText: isMainPassword ? !_isPasswordVisible : !_isConfirmPasswordVisible,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
        prefixIcon: Icon(icon, color: iconColor),
        suffixIcon: IconButton(
          icon: Icon(
            (isMainPassword ? _isPasswordVisible : _isConfirmPasswordVisible)
                ? Icons.visibility
                : Icons.visibility_off,
            color: iconColor,
          ),
          onPressed: () {
            setState(() {
              if (isMainPassword) {
                _isPasswordVisible = !_isPasswordVisible;
              } else {
                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
              }
            });
          },
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      ),
      validator: (value) => value == null || value.length < 6 ? "Password must be at least 6 characters" : null,
    ),
  );
}
}