import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // final _fullNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    // _fullNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();  
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showNetworkErrorModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          'No Internet Connection',
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Please check your internet connection and try again.',
          style: TextStyle(color: Color(0xFFB3B3B3)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    try {
      // final fullName = _fullNameController.text.trim();
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all fields')),
        );
        return;
      }

      final supabase = Supabase.instance.client;
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          // 'full_name': fullName,
          'first_name': firstName,
          'last_name': lastName,
        },
      );

      print('Sign-up response: $response');
      print('User after signup: ${response.user}');
      print('Current session after signup: ${supabase.auth.currentSession}');

      if (response.user != null) {
        // Insert user into the users table
        await supabase.from('users').insert({
          'id': response.user!.id,
          'email': email,
          // 'full_name': fullName,
          'first_name': firstName,
          'last_name': lastName,
        });

        print('Inserted user into users table: ${response.user!.id}');

        if (mounted) {
          // Show a confirmation message
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text(
                'Check Your Email',
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'A confirmation email has been sent to $email. Please confirm your email to continue.',
                style: const TextStyle(color: Color(0xFFB3B3B3)),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/login');
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        throw 'Sign-up failed: No user returned';
      }
    } catch (e) {
      print('Registration error: $e');
      if (mounted) {
        if (e.toString().contains('SocketException')) {
          _showNetworkErrorModal();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'CLIQ',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFFFFF),
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Sign Up',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CAF50),
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFF4CAF50),
                      decorationThickness: 2,
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () {
                      context.go('/login');
                    },
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFFB3B3B3),
                      ),
                    ),
                  ),
                ],
              ),
              // const SizedBox(height: 40),
              // TextField(
              //   controller: _fullNameController,
              //   decoration: const InputDecoration(
              //     hintText: 'Full Name',
              //     prefixIcon: Icon(Icons.person_outline),
              //   ),
              //   style: const TextStyle(color: Color(0xFFFFFFFF)),
              // ),
              const SizedBox(height: 16),
              TextField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  hintText: 'First Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                style: const TextStyle(color: Color(0xFFFFFFFF)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  hintText: 'Last Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                style: const TextStyle(color: Color(0xFFFFFFFF)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                style: const TextStyle(color: Color(0xFFFFFFFF)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: const Color(0xFFB3B3B3),
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                style: const TextStyle(color: Color(0xFFFFFFFF)),
                obscureText: !_isPasswordVisible,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _register,
                child: const Text('Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}