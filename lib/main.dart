//flutter build apk --release --target-platform=android-arm64

import 'package:attendance_app_2/signup_screen.dart';
import 'package:attendance_app_2/splash_screen.dart';
import 'package:attendance_app_2/home_screen.dart';  // Import Home Screen
import 'package:attendance_app_2/login_screen.dart';  // Import Login Screen
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:attendance_app_2/sign_up_screen.dart';  // Import SignUp Screen
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:attendance_app_2/theme_notifier.dart';
import 'package:attendance_app_2/scan_sound_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Optional
);


  runApp(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScanFeedbackNotifier()), // ✅ Add this
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
      ],
      child: MyApp(),
    ),);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  // Load the user's theme preference from SharedPreferences
  Future<void> _loadThemePreference() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

   return MaterialApp(
  title: 'Attendance App',
  debugShowCheckedModeBanner: false,

  theme: ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue, // Use primarySwatch for light theme
    useMaterial3: true,         // optional, if you want Material 3 styling
  ),

  darkTheme: ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue.shade900,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  ),

  themeMode: themeNotifier.isDarkMode ? ThemeMode.dark : ThemeMode.light,

  initialRoute: '/',
  routes: {
    '/': (context) => SplashScreen(),
    '/home': (context) => MyHomePage(),
    '/login': (context) => LoginScreen(),
    '/signup': (context) => SignUpPage(),
  },
);

  }
}
