import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfileViewScreen extends StatefulWidget {
  const ProfileViewScreen({super.key});

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _profileImageUrl;
  bool _isLoading = true;
  bool _isEditing = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      final response = await supabase
          .from('users')
          .select('username, first_name, last_name, email, profile_image_url')
          .eq('id', user.id)
          .single();

      setState(() {
        _usernameController.text = response['username'] ?? '';
        _firstNameController.text = response['first_name'] ?? '';
        _lastNameController.text = response['last_name'] ?? '';
        _emailController.text = response['email'] ?? user.email ?? '';
        _profileImageUrl = response['profile_image_url'];
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final fileName = '${user.id}/profile.jpg'; // Consistent with profile_screen.dart
      final filePath = fileName;

      await supabase.storage
          .from('avatars') // Updated to match the correct bucket name
          .upload(filePath, _selectedImage!, fileOptions: const FileOptions(upsert: true));

      final publicUrl = supabase.storage.from('avatars').getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      print('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _updateProfile() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      // Upload new profile image if selected
      final newProfileImageUrl = await _uploadImage() ?? _profileImageUrl;

      // Update user profile in the database
      await supabase.from('users').update({
        'username': _usernameController.text,
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'email': _emailController.text,
        'profile_image_url': newProfileImageUrl,
      }).eq('id', user.id);

      // Update email in Supabase Auth if it has changed
      if (_emailController.text != user.email) {
        await supabase.auth.updateUser(
          UserAttributes(email: _emailController.text),
        );
      }

      // Update password if provided
      if (_passwordController.text.isNotEmpty) {
        await supabase.auth.updateUser(
          UserAttributes(password: _passwordController.text),
        );
      }

      setState(() {
        _profileImageUrl = newProfileImageUrl;
        _isEditing = false;
        _selectedImage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      print('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
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
          'Profile',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFFFFF),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              context.go('/login');
            },
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
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF4CAF50),
                          backgroundImage: _selectedImage != null
                              ? FileImage(_selectedImage!)
                              : _profileImageUrl != null
                                  ? NetworkImage(_profileImageUrl!)
                                  : null,
                          child: _selectedImage == null && _profileImageUrl == null
                              ? const Icon(Icons.person, color: Colors.white, size: 50)
                              : null,
                        ),
                        if (_isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.white),
                              onPressed: _pickImage,
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _usernameController,
                    enabled: _isEditing,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: const TextStyle(color: Color(0xFFB3B3B3)),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Color(0xFFFFFFFF)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _firstNameController,
                    enabled: _isEditing,
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      labelStyle: const TextStyle(color: Color(0xFFB3B3B3)),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Color(0xFFFFFFFF)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _lastNameController,
                    enabled: _isEditing,
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      labelStyle: const TextStyle(color: Color(0xFFB3B3B3)),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Color(0xFFFFFFFF)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    enabled: _isEditing,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Color(0xFFB3B3B3)),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Color(0xFFFFFFFF)),
                  ),
                  const SizedBox(height: 16),
                  if (_isEditing)
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'New Password (optional)',
                        labelStyle: const TextStyle(color: Color(0xFFB3B3B3)),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: Color(0xFFFFFFFF)),
                    ),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_isEditing) {
                          _updateProfile();
                        } else {
                          setState(() {
                            _isEditing = true;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: Text(
                        _isEditing ? 'Save Changes' : 'Edit Profile',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  if (_isEditing)
                    Center(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _selectedImage = null;
                            _fetchUserData(); // Revert changes
                          });
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF121212),
        selectedItemColor: const Color(0xFF4CAF50),
        unselectedItemColor: const Color(0xFFB3B3B3),
        currentIndex: 3, // Profile tab selected
        onTap: (index) {
          if (index == 0) {
            context.go('/home');
          } else if (index == 1) {
            context.go('/friends');
          } else if (index == 2) {
            context.go('/chats');
          } else if (index == 3) {
            // Already on Profile
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