import 'package:attendance_app_2/scan_sound_notifier.dart';
import 'package:attendance_app_2/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
// Import your Login screen
import 'package:attendance_app_2/profile_screen.dart'; // Import your Profile screen

class SettingsScreen extends StatefulWidget {
  final String updatedUsername;

  const SettingsScreen({super.key, this.updatedUsername = ''});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String username = "Loading";
  String email = "Loading";
  bool isDarkMode = false;
  bool isLoading = true;
  bool isNotificationToneExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  // Fetch the current user's profile information
  Future<void> _fetchUserProfile() async {
    var currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setState(() {
        email = currentUser.email ?? "No Email";
      });

      // Fetch username from Firestore
      try {
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();

        if (userDoc.exists) {
          setState(() {
            username = userDoc['username'] ?? "No Username";
          });
        }
      } catch (e) {
        // Handle any errors that occur during profile fetching
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching profile: $e')));
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  // Function to log out the user
  logout() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Logout'),
          content: Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close the dialog
                await FirebaseAuth.instance.signOut();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false, // Remove all previous routes
                );
              },
              child: Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // Function to delete the account
  /// Function to delete user account and data
  Future<void> _deleteAccount() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        setState(() {
          isLoading = true;
        });

        // Delete user data from Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();

        // Delete user from Firebase Authentication
        await user.delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully!')),
        );

        // Navigate to login screen
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting account: $e')));
    }
  }

  /// Confirmation dialog before deleting the account
  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      barrierDismissible: !isLoading,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Account Deletion'),
          content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed:
                  isLoading
                      ? null
                      : () {
                        Navigator.pop(context);
                      },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed:
                  isLoading
                      ? null
                      : () {
                        Navigator.pop(context);
                        _deleteAccount();
                      },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      backgroundColor:
          themeNotifier.isDarkMode ? Colors.black : Colors.grey[200],
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor:
            themeNotifier.isDarkMode ? Colors.blue.shade900 : Colors.blue,
        elevation: 0,
      ),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Column(
                  children: [
                    // Profile Section with Gradient Card
                    _buildProfileSection(),
                    const SizedBox(height: 20),
                    // Settings Options with Card Design
                    _buildSettingsCard([
                      _buildSettingsItem(
                        Icons.dark_mode,
                        "Dark Mode",
                        trailing: Switch(
                          value: themeNotifier.isDarkMode,
                          onChanged: (value) {
                            themeNotifier.toggleTheme(); // Toggle theme here
                          },
                        ),
                      ),
                      _buildSettingsItem(
                        Icons.notifications,
                        "Notification Tones",
                        trailing: Icon(
                          isNotificationToneExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color:
                              themeNotifier.isDarkMode
                                  ? Colors.white
                                  : Colors.black,
                        ),
                        onTap: () {
                          setState(() {
                            isNotificationToneExpanded =
                                !isNotificationToneExpanded;
                          });
                        },
                      ),
                      if (isNotificationToneExpanded) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 32.0),
                          child: _buildSettingsItem(
                            Icons.qr_code_2,
                            "Sound on QR Scan",
                            trailing: Switch(
                              value:
                                  Provider.of<ScanFeedbackNotifier>(
                                    context,
                                  ).soundEnabled,
                              onChanged: (value) {
                                Provider.of<ScanFeedbackNotifier>(
                                  context,
                                  listen: false,
                                ).setSoundEnabled(value);
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 32.0),
                          child: _buildSettingsItem(
                            Icons.vibration,
                            "Vibrate on QR Scan",
                            trailing: Switch(
                              value:
                                  Provider.of<ScanFeedbackNotifier>(
                                    context,
                                  ).vibrationEnabled,
                              onChanged: (value) {
                                Provider.of<ScanFeedbackNotifier>(
                                  context,
                                  listen: false,
                                ).setVibrationEnabled(value);
                              },
                            ),
                          ),
                        ),
                      ],

                      _buildSettingsItem(Icons.lock, "Privacy"),
                    ]),
                    _buildSettingsCard([
                      _buildSettingsItem(
                        Icons.person_add,
                        "Add Account",
                        onTap: _addAccount,
                      ),
                      _buildSettingsItem(
                        Icons.logout,
                        "Log Out",
                        iconColor: Colors.red,
                        textColor: Colors.red,
                        onTap: logout,
                      ),
                      _buildSettingsItem(
                        Icons.delete,
                        "Delete Account",
                        iconColor: Colors.red,
                        textColor: Colors.red,
                        onTap: _confirmDeleteAccount,
                      ),
                    ]),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
    );
  }

  // Extract Profile Section Widget
  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: ListTile(
        leading:
            FirebaseAuth.instance.currentUser?.photoURL != null
                ? CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(
                    FirebaseAuth.instance.currentUser!.photoURL!,
                  ),
                )
                : CircleAvatar(radius: 40, child: Icon(Icons.person)),
        title: Text(
          username, // Use the updated username
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(email, style: TextStyle(color: Colors.white70)),
        trailing: const Icon(Icons.edit, color: Colors.white),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfileScreen()),
          );
        },
      ),
    );
  }

  // Extract Settings Item Widget
  Widget _buildSettingsItem(
    IconData icon,
    String text, {
    Widget? trailing,
    Color? iconColor,
    Color? textColor,
    Function()? onTap,
  }) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final currentIconColor =
        iconColor ?? (themeNotifier.isDarkMode ? Colors.white : Colors.black);
    final currentTextColor =
        textColor ?? (themeNotifier.isDarkMode ? Colors.white : Colors.black);

    return ListTile(
      leading: Icon(icon, color: currentIconColor),
      title: Text(
        text,
        style: TextStyle(color: currentTextColor, fontSize: 16),
      ),
      trailing:
          trailing ??
          const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
      onTap: onTap,
    );
  }

  // Build Settings Card
  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      child: Column(children: children),
    );
  }

  void _addAccount() {}
}
