import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('No user logged in, redirecting to login');
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      final response = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .single();

      print('User data fetched: $response');
      setState(() {
        _userData = response;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text(
          'Cliq',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFFFFF),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                context.go('/profile-view');
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF1E1E1E),
                backgroundImage: _userData != null && _userData!['profile_image_url'] != null
                    ? NetworkImage(_userData!['profile_image_url'])
                    : null,
                child: _userData == null || _userData!['profile_image_url'] == null
                    ? const Icon(
                        Icons.person,
                        color: Color(0xFFB3B3B3),
                        size: 20,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4CAF50),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hey, ${_userData?['username'] ?? 'User'}!',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Recent Chats',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF4CAF50),
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: const Text(
                            'Friend 1',
                            style: TextStyle(color: Color(0xFFFFFFFF)),
                          ),
                          subtitle: const Text(
                            'Last message preview...',
                            style: TextStyle(color: Color(0xFFB3B3B3)),
                          ),
                          onTap: () {
                            // Navigate to chat screen (to be implemented)
                          },
                        ),
                        const Divider(color: Color(0xFF2E2E2E), height: 1),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF4CAF50),
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: const Text(
                            'Friend 2',
                            style: TextStyle(color: Color(0xFFFFFFFF)),
                          ),
                          subtitle: const Text(
                            'Last message preview...',
                            style: TextStyle(color: Color(0xFFB3B3B3)),
                          ),
                          onTap: () {
                            // Navigate to chat screen (to be implemented)
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add friend or start new chat (to be implemented)
        },
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF121212),
        selectedItemColor: const Color(0xFF4CAF50),
        unselectedItemColor: const Color(0xFFB3B3B3),
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) {
            // Already on Home
          } else if (index == 1) {
            context.go('/friends');
          } else if (index == 2) {
            context.go('/chats');
          } else if (index == 3) {
            context.go('/profile-view');
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}