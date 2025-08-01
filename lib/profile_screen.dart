import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'settings_screen.dart';
import 'package:attendance_app_2/theme_notifier.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? userEmail;
  String? _fullPhoneNumber;
  String? firestoreUserId;
  String? originalPhoneNumber;
  bool isLoading = true;
  bool isVerifying = false;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    try {
      var currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        userEmail = currentUser.email;
        var userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: userEmail)
            .get();

        if (userSnapshot.docs.isNotEmpty) {
          var userData = userSnapshot.docs.first;
          var data = userData.data();
          setState(() {
            firestoreUserId = userData.id;
            _usernameController.text = data['username'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            originalPhoneNumber = data['phone'] ?? '';
            _fullPhoneNumber = data['phone'] ?? ''; // in case stored in full format
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load profile: $e")),
      );
    }
  }

  Future<void> _verifyPhoneNumberAndUpdate() async {
    if (_fullPhoneNumber == null || _fullPhoneNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a valid phone number")),
      );
      return;
    }

    setState(() => isVerifying = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _fullPhoneNumber!,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.currentUser?.updatePhoneNumber(credential);
        await _updateFirestorePhoneNumber(_fullPhoneNumber!);
        setState(() => isVerifying = false);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Verification failed: ${e.message}")),
        );
      },
      codeSent: (String verificationId, int? resendToken) async {
        String smsCode = await _showOTPDialog();

        if (smsCode.isNotEmpty) {
          try {
            PhoneAuthCredential credential = PhoneAuthProvider.credential(
              verificationId: verificationId,
              smsCode: smsCode,
            );
            await FirebaseAuth.instance.currentUser?.updatePhoneNumber(credential);
            await _updateFirestorePhoneNumber(_fullPhoneNumber!);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("OTP verification failed: $e")),
            );
          }
        }

        setState(() => isVerifying = false);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<String> _showOTPDialog() async {
    String otp = "";
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final otpController = TextEditingController();
        return AlertDialog(
          title: const Text("Enter OTP"),
          content: TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: "OTP"),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (otpController.text.trim().isEmpty) return;
                otp = otpController.text.trim();
                Navigator.of(context).pop();
              },
              child: const Text("Verify"),
            ),
          ],
        );
      },
    );
    return otp;
  }

  Future<void> _updateFirestorePhoneNumber(String phone) async {
    if (firestoreUserId != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(firestoreUserId)
          .update({'phone': phone});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number updated successfully!")),
      );
    }
  }

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      if (_fullPhoneNumber != originalPhoneNumber) {
        _verifyPhoneNumberAndUpdate();
      } else {
        _updateProfile();
      }
    }
  }

  Future<void> _updateProfile() async {
    if (firestoreUserId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(firestoreUserId)
            .update({
              'username': _usernameController.text,
              'phone': _phoneController.text,
            });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                SettingsScreen(updatedUsername: _usernameController.text),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update profile: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      backgroundColor: themeNotifier.isDarkMode ? Colors.black : Colors.grey[200],
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: themeNotifier.isDarkMode ? Colors.blue.shade900 : Colors.blue,
        elevation: 0,
      ),
      body: isLoading || isVerifying
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color.fromARGB(255, 13, 62, 102),
                                    Colors.blueAccent,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.person, size: 50, color: Colors.blue[800]),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "Update your profile information",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: themeNotifier.isDarkMode ? Colors.white : Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 30),
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: "Username",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                prefixIcon: const Icon(Icons.person, color: Colors.blue),
                              ),
                              validator: (value) =>
                                  value!.isEmpty ? "Username cannot be empty" : null,
                            ),
                            const SizedBox(height: 20),
                            // IntlPhoneField(
                            //   controller: _phoneController,
                            //   initialCountryCode: 'IN',
                            //   decoration: InputDecoration(
                            //     labelText: 'Phone Number',
                            //     border: OutlineInputBorder(
                            //       borderRadius: BorderRadius.circular(10),
                            //     ),
                            //   ),
                            //   onChanged: (phone) {
                            //     _fullPhoneNumber = phone.completeNumber;
                            //   },
                            //   onCountryChanged: (country) {
                            //     print('Country changed to: ${country.name} (${country.dialCode})');
                            //   },
                            //   validator: (value) {
                            //     if (value == null || value.completeNumber.isEmpty) {
                            //       return 'Enter a valid phone number';
                            //     }
                            //     return null;
                            //   },
                            // ),
                            // const SizedBox(height: 20),
                            TextFormField(
                              initialValue: userEmail,
                              decoration: InputDecoration(
                                labelText: "Email",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                prefixIcon: const Icon(Icons.email, color: Colors.blue),
                              ),
                              enabled: false,
                            ),
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _saveChanges,
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: themeNotifier.isDarkMode
                                      ? Colors.blue.shade900
                                      : Colors.blue,
                                ),
                                child: const Text(
                                  "Save Changes",
                                  style: TextStyle(fontSize: 16, color: Colors.white),
                                ),
                              ),
                            ),
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
}
