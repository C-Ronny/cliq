import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
// import 'package:uuid/uuid.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchConversations() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('User is not authenticated. Redirecting to login.');
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      print('Logged-in user ID: ${user.id}');

      final conversationsResponse = await supabase
          .from('conversations')
          .select('''
            id, name, updated_at,
            conversation_members!inner(user_id)
          ''')
          .eq('conversation_members.user_id', user.id)
          .order('updated_at', ascending: false);

      print('Conversations response: $conversationsResponse');

      final conversations = conversationsResponse as List<dynamic>;

      for (var conv in conversations) {
        final messages = await supabase
            .from('messages')
            .select('id, content, media_url, media_type, created_at, sender_id')
            .eq('conversation_id', conv['id'])
            .order('created_at', ascending: false)
            .limit(1);
        conv['messages'] = messages;
      }

      final unreadCounts = await supabase
          .from('unread_messages')
          .select('conversation_id, message_id')
          .eq('user_id', user.id);

      final List<Map<String, dynamic>> enrichedConversations = [];
      for (var conv in conversations) {
        final members = await supabase
            .from('conversation_members')
            .select('user_id, users(username, profile_image_url)')
            .eq('conversation_id', conv['id']);
        print('Members for conversation ${conv['id']}: $members');

        String displayName = conv['name'] ?? '';
        String? profileImageUrl;
        if (conv['name'] == null) {
          final otherMember = members.firstWhere(
            (m) => m['user_id'] != user.id,
            orElse: () => {
              'users': {'username': 'Unknown User', 'profile_image_url': null}
            },
          );
          print('Other member: $otherMember');
          displayName = otherMember['users']['username'] ?? 'Unknown User';
          profileImageUrl = otherMember['users']['profile_image_url'];
          print('Display name for conversation ${conv['id']}: $displayName');
        }

        final messages = (conv['messages'] as List<dynamic>?) ?? [];
        final lastMessage = messages.isNotEmpty ? messages.first : null;

        final unreadCount = unreadCounts
            .where((unread) => unread['conversation_id'] == conv['id'])
            .length;

        enrichedConversations.add({
          'id': conv['id'],
          'name': displayName,
          'profile_image_url': profileImageUrl,
          'last_message': lastMessage,
          'unread_count': unreadCount,
          'updated_at': conv['updated_at'],
        });
      }

      setState(() {
        _conversations = enrichedConversations;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching conversations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chats: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupRealtimeSubscription() {
    final supabase = Supabase.instance.client;
    _channel = supabase.channel('conversations');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            _fetchConversations();
          },
        )
        .subscribe();
  }

  Future<void> _startNewConversation() async {
    final friend = await _showFriendSearchDialog();
    if (friend == null) return;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final existingConversation = await supabase
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', user.id)
        .inFilter(
          'conversation_id',
          (await supabase
                  .from('conversation_members')
                  .select('conversation_id')
                  .eq('user_id', friend['id']))
              .map((m) => m['conversation_id'])
              .toList(),
        )
        .maybeSingle();

    String conversationId;
    if (existingConversation != null) {
      conversationId = existingConversation['conversation_id'];
    } else {
      final newConversation = await supabase.from('conversations').insert({
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select('id').single();

      conversationId = newConversation['id'];

      await supabase.from('conversation_members').insert([
        {'conversation_id': conversationId, 'user_id': user.id},
        {'conversation_id': conversationId, 'user_id': friend['id']},
      ]);
    }

    if (mounted) {
      context.push('/chat/$conversationId');
    }
  }

  Future<Map<String, dynamic>?> _showFriendSearchDialog() async {
    final TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> friends = [];
    List<Map<String, dynamic>> filteredFriends = [];
    String? errorMessage;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final friendsResponse = await supabase
          .from('friends')
          .select('user_id, friend_id, users!friends_friend_id_fkey(username, profile_image_url)')
          .eq('user_id', user.id);

      print('Friends response: $friendsResponse');

      for (var friendship in friendsResponse) {
        friends.add({
          'id': friendship['friend_id'],
          'username': friendship['users']['username'],
          'profile_image_url': friendship['users']['profile_image_url'],
        });
      }
      filteredFriends = List.from(friends);
    } catch (e) {
      errorMessage = 'Error loading friends: $e';
    }

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text(
                'New Chat',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search friends...',
                      hintStyle: TextStyle(color: Color(0xFFB3B3B3)),
                      filled: true,
                      fillColor: Color(0xFF2A2A2A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) {
                      setDialogState(() {
                        filteredFriends = friends
                            .where((friend) => friend['username']
                                .toLowerCase()
                                .contains(value.toLowerCase()))
                            .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    width: double.maxFinite,
                    child: filteredFriends.isEmpty && errorMessage == null
                        ? const Center(
                            child: Text(
                              'No friends found. Add some friends to start a chat!',
                              style: TextStyle(color: Color(0xFFB3B3B3)),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredFriends.length,
                            itemBuilder: (context, index) {
                              final friend = filteredFriends[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundImage: friend['profile_image_url'] != null
                                      ? CachedNetworkImageProvider(friend['profile_image_url'])
                                      : null,
                                  child: friend['profile_image_url'] == null
                                      ? const Icon(Icons.person, color: Colors.white)
                                      : null,
                                ),
                                title: Text(
                                  friend['username'],
                                  style: const TextStyle(color: Colors.white),
                                ),
                                onTap: () {
                                  Navigator.pop(context, friend);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'Cliq',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFFFFF),
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              'Chats',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFFB3B3B3),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            onPressed: () {
              context.go('/profile');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchConversations,
        color: const Color(0xFF4CAF50),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4CAF50),
                ),
              )
            : _conversations.isEmpty
                ? const Center(
                    child: Text(
                      'No chats yet. Start a new conversation!',
                      style: TextStyle(color: Color(0xFFB3B3B3)),
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = _conversations[index];
                      final lastMessage = conversation['last_message'];
                      final messageContent = lastMessage != null
                          ? (lastMessage['media_type'] != null
                              ? lastMessage['media_type'] == 'voice_note'
                                  ? 'Voice Note'
                                  : lastMessage['media_type'].toString().capitalize()
                              : lastMessage['content'] ?? '')
                          : '';
                      final truncatedMessage =
                          messageContent.length > 20 ? '${messageContent.substring(0, 20)}...' : messageContent;

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 30,
                          backgroundImage: conversation['profile_image_url'] != null
                              ? CachedNetworkImageProvider(conversation['profile_image_url'])
                              : null,
                          child: conversation['profile_image_url'] == null
                              ? const Icon(Icons.group, color: Colors.white)
                              : null,
                        ),
                        title: Text(
                          conversation['name'],
                          style: const TextStyle(
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          truncatedMessage,
                          style: const TextStyle(color: Color(0xFFB3B3B3)),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              timeago.format(DateTime.parse(conversation['updated_at'])),
                              style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 12),
                            ),
                            if (conversation['unread_count'] > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  conversation['unread_count'].toString(),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          final supabase = Supabase.instance.client;
                          supabase
                              .from('unread_messages')
                              .delete()
                              .eq('user_id', supabase.auth.currentUser!.id)
                              .eq('conversation_id', conversation['id']);
                          context.push('/chat/${conversation['id']}');
                        },
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewConversation,
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF121212),
        selectedItemColor: const Color(0xFF4CAF50),
        unselectedItemColor: const Color(0xFFB3B3B3),
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            context.go('/home');
          } else if (index == 1) {
            context.go('/friends');
          } else if (index == 2) {
          } else if (index == 3) {
            context.go('/profile');
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

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}