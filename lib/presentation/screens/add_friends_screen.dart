import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class AddFriendsScreen extends StatefulWidget {
  final String callId;
  const AddFriendsScreen({super.key, required this.callId});

  @override
  State<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends State<AddFriendsScreen> {
  List<Map<String, dynamic>> _friends = [];
  List<String> _currentParticipants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      // Fetch current participants
      final callData = await supabase
          .from('video_calls')
          .select('participants')
          .eq('id', widget.callId)
          .single();

      final participants = (callData['participants'] as List<dynamic>).cast<String>();

      // Fetch friends
      final friendsResponse = await supabase
          .from('friends')
          .select('friend_id')
          .eq('user_id', user.id);

      final friendIds = friendsResponse.map((f) => f['friend_id'] as String).toList();
      final friendsData = await supabase
          .from('users')
          .select('id, username, profile_image_url')
          .inFilter('id', friendIds);

      final friends = friendsData
          .where((f) => !participants.contains(f['id']))
          .toList();

      setState(() {
        _friends = friends;
        _currentParticipants = participants;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching friends: $e');
      if (mounted) {
        context.go('/home');
      }
    }
  }

  Future<void> _inviteFriend(String friendId) async {
    try {
      final supabase = Supabase.instance.client;

      // Fetch current participants
      final callData = await supabase
          .from('video_calls')
          .select('participants')
          .eq('id', widget.callId)
          .single();

      final participants = (callData['participants'] as List<dynamic>).cast<String>();
      if (participants.length >= 4) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This call is full')),
          );
        }
        return;
      }

      final updatedParticipants = [...participants, friendId];
      await supabase
          .from('video_calls')
          .update({'participants': updatedParticipants})
          .eq('id', widget.callId);

      setState(() {
        _currentParticipants = updatedParticipants;
        _friends = _friends.where((f) => f['friend_id'] != friendId).toList();
      });
    } catch (e) {
      print('Error inviting friend: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error inviting friend: $e')),
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
          'Catchup Call',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFFFFF),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () {
                context.pop();
              },
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
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Add Friends to the Call',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _friends.length,
                    itemBuilder: (context, index) {
                      final friend = _friends[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF4CAF50),
                            backgroundImage: friend['profile_image_url'] != null
                                ? NetworkImage(friend['profile_image_url'])
                                : null,
                            child: friend['profile_image_url'] == null
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          title: Text(
                            friend['username'],
                            style: const TextStyle(color: Color(0xFFFFFFFF)),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _inviteFriend(friend['id']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Invite'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF121212),
        selectedItemColor: const Color(0xFF4CAF50),
        unselectedItemColor: const Color(0xFFB3B3B3),
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) {
            context.go('/home');
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