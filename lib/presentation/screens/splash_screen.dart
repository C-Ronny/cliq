import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      await Future.delayed(const Duration(seconds: 2)); // simulate loading

      if (!mounted) return; // Check if the widget is still mounted before navigating

      if (user != null) {
        context.go('/home');
      } else {  
        context.go('/login');
      }
    } catch (e) {
      context.go('/login'); // Fallback
    }
  }

  static const Color customLightGreen = Color(0xFF76FF03);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.cyan.shade900,
      body: Center(
        child: Text(
          'Cliq',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: customLightGreen,
          ),
        ),
      ),
    );
  }
  
}