import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _usernameController = TextEditingController();
  File? _profileImage;
  final _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkProfileStatus();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _checkProfileStatus() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      print('No user logged in, redirecting to login');
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    print('Checking profile status for user ID: ${user.id}');
    final response = await supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    print('Profile check response: $response');
    if (response != null) {
      final username = response['username'] as String?;
      final profileImageUrl = response['profile_image_url'] as String?;
      if (username != null && username.trim().isNotEmpty) {
        print('Profile already set up (username: $username, profile_image_url: $profileImageUrl), redirecting to home');
        if (mounted) {
          context.go('/home');
        }
      }
    }
  }

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        _showSettingsModal();
      }
      return false;
    }
    return false;
  }

  void _showPermissionModal(ImageSource source) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          'Camera Access Required',
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Cliq needs access to your camera to take profile pictures. Please grant permission to continue.',
          style: TextStyle(color: Color(0xFFB3B3B3)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Deny',
              style: TextStyle(color: Color(0xFFB3B3B3)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final granted = await _requestCameraPermission();
              if (granted && mounted) {
                _pickImage(source);
              }
            },
            child: const Text('Allow'),
          ),
        ],
      ),
    );
  }

  void _showSettingsModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          'Camera Permission Denied',
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Camera access is required to take profile pictures. Please enable it in your device settings.',
          style: TextStyle(color: Color(0xFFB3B3B3)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFFB3B3B3)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final status = await Permission.camera.status;
    if (status.isDenied) {
      if (mounted) {
        _showPermissionModal(source);
      }
      return;
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        _showSettingsModal();
      }
      return;
    }

    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
  setState(() {
    _isLoading = true;
  });

  try {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) throw 'No user logged in';

    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    String? profileImageUrl;
    if (_profileImage != null) {
      final fileName = '${user.id}/profile.jpg';
      await supabase.storage.from('avatars').upload(fileName, _profileImage!);
      profileImageUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      print('Profile image uploaded: $profileImageUrl');
    } else {
      print('No profile image uploaded, proceeding without profile_image_url');
    }

    // Check if the user's row exists in the users table
    final existingUser = await supabase
        .from('users')
        .select('id, first_name, last_name')
        .eq('id', user.id)
        .maybeSingle();

    if (existingUser == null) {
      // Row doesn't exist, insert it
      print('User row does not exist, inserting new row');
      await supabase.from('users').insert({
        'id': user.id,
        'email': user.email,
        'username': username,
        'profile_image_url': profileImageUrl,
        'first_name': user.userMetadata?['first_name'] ?? '',
        'last_name': user.userMetadata?['last_name'] ?? '',
      });
    } else {
      // Row exists, update it
      print('User row exists, updating row');
      await supabase.from('users').update({
        'username': username,
        'profile_image_url': profileImageUrl,
        'first_name': existingUser['first_name'],
        'last_name': existingUser['last_name'],
      }).eq('id', user.id);
    }

    print('Profile saved successfully for user ID: ${user.id}');
    if (mounted) {
      context.go('/home');
    }
  } catch (e) {
    print('Error saving profile: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
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
                'Set Up Your Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFFFFF),
                ),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.camera_alt),
                          title: const Text('Take a Photo'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(ImageSource.camera);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: const Text('Choose from Gallery'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(ImageSource.gallery);
                          },
                        ),
                      ],
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF1E1E1E),
                  backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                  child: _profileImage == null
                      ? const Icon(
                          Icons.camera_alt,
                          size: 40,
                          color: Color(0xFFB3B3B3),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tap to add a profile picture',
                style: TextStyle(
                  color: Color(0xFFB3B3B3),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  hintText: 'Username',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                style: const TextStyle(color: Color(0xFFFFFFFF)),
              ),
              const SizedBox(height: 40),
              _isLoading
                  ? const CircularProgressIndicator(
                      color: Color(0xFF4CAF50),
                    )
                  : ElevatedButton(
                      onPressed: _saveProfile,
                      child: const Text('Save Profile'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}