import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use FirebaseOptions when running on the web
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDfuAPKb2WdK2D4jUhVPFNajNacsv0B_PA",
        authDomain: "find-74ab9.firebaseapp.com",
        projectId: "find-74ab9",
        storageBucket: "find-74ab9.firebasestorage.app",
        messagingSenderId: "589831949774",
        appId: "1:589831949774:web:81f391fe1859731177ef9f",
        measurementId: "G-NE3ECSQV54",
      ),
    );
  } else {
    await Firebase.initializeApp(); // For mobile platforms
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF000B8C),
      body: Center(
        child: Image(
          image: AssetImage('assets/images/logo.png'),
          height: 220,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
