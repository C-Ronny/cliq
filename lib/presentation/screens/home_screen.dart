import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _videoCalls = [];
  List<String> _friendIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
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

    // Fetch user's friends
    final friendsResponse = await supabase
        .from('friends')
        .select('friend_id')
        .eq('user_id', user.id);

    final friendIds = friendsResponse.map((f) => f['friend_id'] as String).toList();
    print('Friends: $friendIds');
    setState(() {
      _friendIds = friendIds;
    });

    // Fetch all video calls
    final callsResponse = await supabase.from('video_calls').select();

    // Filter calls to only include those with at least one friend
    final filteredCalls = callsResponse.where((call) {
      final participants = (call['participants'] as List<dynamic>).cast<String>();
      return participants.any((participantId) => friendIds.contains(participantId));
    }).toList();

    // Fetch participant details separately
    for (var call in filteredCalls) {
      final participantIds = (call['participants'] as List<dynamic>).cast<String>();
      final participantsData = await supabase
          .from('users')
          .select('username')
          .inFilter('id', participantIds);

      call['participant_names'] = participantsData.map((p) => p['username'] as String).join(', ');
    }

    print('Filtered video calls: $filteredCalls');
    setState(() {
      _videoCalls = filteredCalls.cast<Map<String, dynamic>>();
      _isLoading = false;
    });
  } catch (e) {
    print('Error fetching data: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading video calls: $e')),
      );
      context.go('/login');
    }
  }
}

  Future<void> _createVideoCall() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      final response = await supabase.from('video_calls').insert({
        'admin_id': user.id,
        'participants': [user.id],
        'is_locked': false,
      }).select().single();

      print('Created video call: $response');
      if (mounted) {
        context.push('/call/${response['id']}');
      }
    } catch (e) {
      print('Error creating video call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating video call: $e')),
        );
      }
    }
  }

  Future<void> _joinCall(String callId, bool isLocked, List<String> participants) async {
    if (isLocked) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This call is locked')),
        );
      }
      return;
    }

    if (participants.length >= 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This call is full')),
        );
      }
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      // Update participants list
      final updatedParticipants = [...participants, user.id];
      await supabase
          .from('video_calls')
          .update({'participants': updatedParticipants})
          .eq('id', callId);

      print('Joined call $callId');
      if (mounted) {
        context.push('/call/$callId');
      }
    } catch (e) {
      print('Error joining call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining call: $e')),
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
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFF1E1E1E),
                child: Icon(
                  Icons.person,
                  color: Color(0xFFB3B3B3),
                  size: 20,
                ),
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
          : _videoCalls.isEmpty
              ? const Center(
                  child: Text(
                    'Connect with friends!',
                    style: TextStyle(
                      fontSize: 20,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                  itemCount: _videoCalls.length,
                  itemBuilder: (context, index) {
                    final call = _videoCalls[index];
                    final participants = (call['participants'] as List<dynamic>).cast<String>();
                    final isLocked = call['is_locked'] as bool;
                    final isFull = participants.length >= 4;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16.0),
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
                      child: ListTile(
                        leading: const CircleAvatar(
                          radius: 30,
                          backgroundColor: Color(0xFF4CAF50),
                          child: Icon(Icons.videocam, color: Colors.white, size: 30),
                        ),
                        title: const Text(
                          'Catchup Call',
                          style: TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'On Call: ${call['participant_names']}',
                          style: const TextStyle(color: Color(0xFFB3B3B3)),
                        ),
                        trailing: isFull
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  'FULL',
                                  style: TextStyle(
                                    color: Color(0xFFB3B3B3),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : ElevatedButton(
                                onPressed: () => _joinCall(call['id'], isLocked, participants),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text('Ring'),
                              ),
                        onTap: () => _joinCall(call['id'], isLocked, participants),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createVideoCall,
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