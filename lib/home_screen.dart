import 'package:attendance_app_2/add_student_screen.dart';
import 'package:attendance_app_2/scan_qr_screen.dart';
import 'package:attendance_app_2/settings_screen.dart';
import 'package:attendance_app_2/student_list_screen.dart';
import 'package:attendance_app_2/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _cacheClassData() async {
    final userId = _auth.currentUser!.uid;
    final snapshot =
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('classes')
            .get();

    final prefs = await SharedPreferences.getInstance();
    final Map<String, String> classMap = {
      for (var doc in snapshot.docs)
        doc.id: doc['className'] ?? 'Unnamed Class',
    };

    await prefs.setString('cached_classes', jsonEncode(classMap));
  }

  Future<void> _deleteClass(String classId) async {
    try {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('classes')
          .doc(classId)
          .delete();

      await _cacheClassData(); // refresh cache

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class deleted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting class: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _renameClass(String classId, String oldClassName) async {
    final TextEditingController controller = TextEditingController(
      text: oldClassName,
    );
    String? errorText;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Rename Class'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Enter new class name',
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: const Text('Rename'),
                  onPressed: () async {
                    final newName = controller.text.trim();
                    if (newName.isEmpty) {
                      setState(() {
                        errorText = 'Class name cannot be empty';
                      });
                      return;
                    }
                    if (newName == oldClassName) {
                      Navigator.pop(context);
                      return;
                    }

                    try {
                      final userId = _auth.currentUser!.uid;

                      final duplicateQuery =
                          await _firestore
                              .collection('users')
                              .doc(userId)
                              .collection('classes')
                              .where('className', isEqualTo: newName)
                              .get();

                      final isDuplicate = duplicateQuery.docs.any(
                        (doc) => doc.id != classId,
                      );

                      if (isDuplicate) {
                        setState(() {
                          errorText = 'A class with that name already exists.';
                        });
                        return;
                      }

                      await _firestore
                          .collection('users')
                          .doc(userId)
                          .collection('classes')
                          .doc(classId)
                          .update({'className': newName});

                      await _cacheClassData(); // refresh cache

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Class renamed successfully!'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error renaming class: $e'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    double height = 90,
    double fontSize = 18,
  }) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final buttonTextColor =
        themeNotifier.isDarkMode ? Colors.white : Colors.black;
    final buttonIconColor =
        themeNotifier.isDarkMode ? Colors.white : Colors.black;

    return SizedBox(
      width: 320,
      height: height,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: buttonIconColor),
        label: Text(
          label,
          style: TextStyle(fontSize: fontSize, color: buttonTextColor),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              themeNotifier.isDarkMode ? Colors.blue[900] : Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 5,
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildClassCard(DocumentSnapshot classDoc) {
    final data = classDoc.data() as Map<String, dynamic>;
    final className = data['className'];
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final textColor = themeNotifier.isDarkMode ? Colors.white : Colors.black;

    return GestureDetector(
      onLongPress: () => _showClassOptions(classDoc.id, className),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 18,
          ),
          title: Text(
            'Class $className',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.blueGrey),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => StudentListScreen(
                      classId: classDoc.id,
                      className: className,
                      userId: _auth.currentUser!.uid,
                    ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showClassOptions(String classId, String className) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Rename Class'),
                onTap: () {
                  Navigator.pop(context);
                  _renameClass(classId, className);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Class'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteClass(classId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _cacheClassData();
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final textColor = themeNotifier.isDarkMode ? Colors.white : Colors.black;
    final iconColor =
        themeNotifier.isDarkMode ? Colors.white70 : Colors.black87;

    final userId = _auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: themeNotifier.isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor:
            themeNotifier.isDarkMode ? Colors.blue.shade900 : Colors.blue,
        title: Text(
          "Attendance App",
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(
              themeNotifier.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: iconColor,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () {
              themeNotifier.toggleTheme();
            },
          ),
          IconButton(
            icon: Icon(Icons.settings, color: iconColor),
            tooltip: "Settings",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildActionButton(
                icon: Icons.camera_alt,
                label: 'Take Attendance',
                height: 100,
                fontSize: 20,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScanScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildActionButton(
                icon: Icons.school,
                label: 'Add New Student',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => AddNewStudentScreen(
                            firestoreUserId: _auth.currentUser!.uid,
                          ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream:
                      _firestore
                          .collection('users')
                          .doc(userId)
                          .collection('classes')
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          'No classes available',
                          style: TextStyle(
                            color:
                                themeNotifier.isDarkMode
                                    ? Colors.white70
                                    : Colors.black54,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }

                    return ListView(
                      children:
                          snapshot.data!.docs.map(_buildClassCard).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
