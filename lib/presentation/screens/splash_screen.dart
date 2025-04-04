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
      print('Checking auth status...');
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      print('User: $user');
      await Future.delayed(const Duration(seconds: 2));
      if (user != null) {
        print('Navigating to /home');
        context.go('/home');
      } else {
        print('Navigating to /login');
        context.go('/login');
      }
    } catch (e) {
      print('Error in auth check: $e');
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