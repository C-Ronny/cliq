import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _incomingRequests = [];
  List<Map<String, dynamic>> _sentRequests = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      // Fetch friends
      final friendsResponse = await supabase
          .from('friends')
          .select('friend_id')
          .eq('user_id', user.id);

      final friendIds = friendsResponse.map((f) => f['friend_id'] as String).toList();
      final friendsData = friendIds.isNotEmpty
          ? await supabase
              .from('users')
              .select('id, username, profile_image_url')
              .inFilter('id', friendIds)
          : [];

      // Fetch incoming friend requests
      final incomingRequestsResponse = await supabase
          .from('friend_requests')
          .select('id, sender_id')
          .eq('receiver_id', user.id)
          .eq('status', 'pending');

      final senderIds = incomingRequestsResponse.map((r) => r['sender_id'] as String).toList();
      final sendersData = senderIds.isNotEmpty
          ? await supabase
              .from('users')
              .select('id, username, profile_image_url')
              .inFilter('id', senderIds)
          : [];

      final requestsWithSenders = incomingRequestsResponse.map((request) {
        final sender = sendersData.firstWhere(
          (s) => s['id'] == request['sender_id'],
          orElse: () => {'username': 'Unknown', 'profile_image_url': null},
        );
        return {
          'id': request['id'],
          'sender_id': request['sender_id'],
          'username': sender['username'],
          'profile_image_url': sender['profile_image_url'],
        };
      }).toList();

      // Fetch sent friend requests
      final sentRequestsResponse = await supabase
          .from('friend_requests')
          .select('id, receiver_id')
          .eq('sender_id', user.id)
          .eq('status', 'pending');

      final receiverIds = sentRequestsResponse.map((r) => r['receiver_id'] as String).toList();
      final receiversData = receiverIds.isNotEmpty
          ? await supabase
              .from('users')
              .select('id, username, profile_image_url')
              .inFilter('id', receiverIds)
          : [];

      final sentRequestsWithReceivers = sentRequestsResponse.map((request) {
        final receiver = receiversData.firstWhere(
          (r) => r['id'] == request['receiver_id'],
          orElse: () => {'username': 'Unknown', 'profile_image_url': null},
        );
        return {
          'id': request['id'],
          'receiver_id': request['receiver_id'],
          'username': receiver['username'],
          'profile_image_url': receiver['profile_image_url'],
        };
      }).toList();

      setState(() {
        _friends = List<Map<String, dynamic>>.from(friendsData);
        _incomingRequests = requestsWithSenders;
        _sentRequests = sentRequestsWithReceivers;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching friends data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading friends: $e')),
        );
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Fetch current friends and pending requests to exclude them
      final friendsResponse = await supabase
          .from('friends')
          .select('friend_id')
          .eq('user_id', user.id);

      final friendIds = friendsResponse.map((f) => f['friend_id'] as String).toList();
      final pendingRequestsResponse = await supabase
          .from('friend_requests')
          .select('receiver_id, sender_id')
          .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
          .eq('status', 'pending');

      final pendingIds = pendingRequestsResponse
          .map((r) => r['sender_id'] == user.id ? r['receiver_id'] : r['sender_id'])
          .cast<String>()
          .toList();

      // Build the query
      var queryBuilder = supabase
          .from('users')
          .select('id, username, profile_image_url')
          .ilike('username', '%$query%')
          .not('id', 'eq', user.id);

      if (friendIds.isNotEmpty) {
        queryBuilder = queryBuilder.not('id', 'in', '(${friendIds.join(',')})');
      }
      if (pendingIds.isNotEmpty) {
        queryBuilder = queryBuilder.not('id', 'in', '(${pendingIds.join(',')})');
      }

      final searchResults = await queryBuilder;

      setState(() {
        _searchResults = searchResults;
        _isSearching = true;
      });
    } catch (e) {
      print('Error searching users: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching users: $e')),
        );
      }
    }
  }

  Future<void> _sendFriendRequest(String receiverId) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase.from('friend_requests').insert({
        'sender_id': user.id,
        'receiver_id': receiverId,
        'status': 'pending',
      });

      setState(() {
        _searchResults = _searchResults.where((r) => r['id'] != receiverId).toList();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!')),
        );
      }
    } catch (e) {
      print('Error sending friend request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending friend request: $e')),
        );
      }
    }
  }

  Future<void> _acceptFriendRequest(String requestId, String senderId) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Update the request status
      await supabase
          .from('friend_requests')
          .update({'status': 'accepted'})
          .eq('id', requestId);

      // Add to friends table (both directions)
      await supabase.from('friends').insert([
        {'user_id': user.id, 'friend_id': senderId},
        {'user_id': senderId, 'friend_id': user.id},
      ]);

      // Fetch updated friends
      final friendsResponse = await supabase
          .from('friends')
          .select('friend_id')
          .eq('user_id', user.id);

      final friendIds = friendsResponse.map((f) => f['friend_id'] as String).toList();
      final friendsData = friendIds.isNotEmpty
          ? await supabase
              .from('users')
              .select('id, username, profile_image_url')
              .inFilter('id', friendIds)
          : [];

      setState(() {
        _incomingRequests = _incomingRequests.where((r) => r['id'] != requestId).toList();
        _friends = List<Map<String, dynamic>>.from(friendsData);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request accepted!')),
        );
      }
    } catch (e) {
      print('Error accepting friend request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting friend request: $e')),
        );
      }
    }
  }

  Future<void> _rejectFriendRequest(String requestId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('friend_requests')
          .update({'status': 'rejected'})
          .eq('id', requestId);

      setState(() {
        _incomingRequests = _incomingRequests.where((r) => r['id'] != requestId).toList();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request rejected')),
        );
      }
    } catch (e) {
      print('Error rejecting friend request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting friend request: $e')),
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
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for friends...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _searchUsers('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Color(0xFFFFFFFF)),
                    onChanged: _searchUsers,
                  ),
                  const SizedBox(height: 24),

                  // Search results
                  if (_isSearching)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Search Results',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_searchResults.isEmpty)
                          const Text(
                            'No users found',
                            style: TextStyle(color: Color(0xFFB3B3B3)),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
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
                                    backgroundImage: user['profile_image_url'] != null
                                        ? NetworkImage(user['profile_image_url'])
                                        : null,
                                    child: user['profile_image_url'] == null
                                        ? const Icon(Icons.person, color: Colors.white)
                                        : null,
                                  ),
                                  title: Text(
                                    user['username'],
                                    style: const TextStyle(color: Color(0xFFFFFFFF)),
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () => _sendFriendRequest(user['id']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4CAF50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text('Add'),
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),

                  // Sent friend requests
                  if (_sentRequests.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sent Requests',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _sentRequests.length,
                          itemBuilder: (context, index) {
                            final request = _sentRequests[index];
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
                                  backgroundImage: request['profile_image_url'] != null
                                      ? NetworkImage(request['profile_image_url'])
                                      : null,
                                  child: request['profile_image_url'] == null
                                      ? const Icon(Icons.person, color: Colors.white)
                                      : null,
                                ),
                                title: Text(
                                  request['username'],
                                  style: const TextStyle(color: Color(0xFFFFFFFF)),
                                ),
                                subtitle: const Text(
                                  'Pending',
                                  style: TextStyle(color: Color(0xFFB3B3B3)),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),

                  // Incoming friend requests
                  if (_incomingRequests.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Friend Requests',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _incomingRequests.length,
                          itemBuilder: (context, index) {
                            final request = _incomingRequests[index];
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
                                  backgroundImage: request['profile_image_url'] != null
                                      ? NetworkImage(request['profile_image_url'])
                                      : null,
                                  child: request['profile_image_url'] == null
                                      ? const Icon(Icons.person, color: Colors.white)
                                      : null,
                                ),
                                title: Text(
                                  request['username'],
                                  style: const TextStyle(color: Color(0xFFFFFFFF)),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check, color: Color(0xFF4CAF50)),
                                      onPressed: () => _acceptFriendRequest(
                                          request['id'], request['sender_id']),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      onPressed: () => _rejectFriendRequest(request['id']),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),

                  // Current friends
                  const Text(
                    'My Friends',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_friends.isEmpty)
                    const Text(
                      'No friends yet',
                      style: TextStyle(color: Color(0xFFB3B3B3)),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
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
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF121212),
        selectedItemColor: const Color(0xFF4CAF50),
        unselectedItemColor: const Color(0xFFB3B3B3),
        currentIndex: 1, // Friends tab selected
        onTap: (index) {
          if (index == 0) {
            context.go('/home');
          } else if (index == 1) {
            // Already on Friends
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