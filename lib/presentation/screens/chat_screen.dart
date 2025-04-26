import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:cliq/utils/audio_utils.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;

  const ChatScreen({super.key, required this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _conversation;
  bool _isLoading = true;
  final TextEditingController _messageController = TextEditingController();
  RealtimeChannel? _channel;
  bool _isRecording = false;
  final AudioUtils _audioUtils = AudioUtils();
  final Map<String, PlayerController> _playerControllers = {};

  @override
  void initState() {
    super.initState();
    _audioUtils.initialize();
    _fetchConversation();
    _fetchMessages();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _messageController.dispose();
    _audioUtils.dispose();
    for (var controller in _playerControllers.values) {
      controller.dispose();
    }
    _playerControllers.clear();
    super.dispose();
  }

  Future<void> _fetchConversation() async {
    try {
      final supabase = Supabase.instance.client;
      final conversationData = await supabase
          .from('conversations')
          .select('''
            id, name, updated_at,
            conversation_members!inner(user_id, users(id, username, profile_image_url))
          ''')
          .eq('id', widget.conversationId)
          .single();

      print('Conversation data: $conversationData');

      final user = supabase.auth.currentUser;
      if (user == null) {
        print('User is not authenticated. Redirecting to login.');
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      print('Logged-in user ID: ${user.id}');

      String displayName = conversationData['name'] ?? '';
      String? profileImageUrl;
      if (conversationData['name'] == null) {
        final members = conversationData['conversation_members'] as List<dynamic>;
        print('Members: $members');
        final otherMember = members.firstWhere(
          (m) => m['user_id'] != user.id,
          orElse: () => {
            'users': {'username': 'Unknown User', 'profile_image_url': null}
          },
        );
        print('Other member: $otherMember');
        displayName = otherMember['users']['username'] ?? 'Unknown User';
        profileImageUrl = otherMember['users']['profile_image_url'];
        print('Display name: $displayName');
      }

      setState(() {
        _conversation = {
          'id': conversationData['id'],
          'name': displayName,
          'profile_image_url': profileImageUrl,
        };
      });
    } catch (e) {
      print('Error fetching conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading conversation: $e')),
        );
      }
    }
  }

  Future<void> _fetchMessages() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('User is not authenticated in _fetchMessages.');
        return;
      }

      print('Fetching messages for conversation ID: ${widget.conversationId}');
      final messagesResponse = await supabase
          .from('messages')
          .select('''
            id, content, media_url, media_type, created_at, sender_id,
            users!messages_sender_id_fkey(username, profile_image_url)
          ''')
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: true);

      print('Messages response: $messagesResponse');

      final messages = List<Map<String, dynamic>>.from(messagesResponse);

      for (var message in messages) {
        if (message['media_type'] == 'voice_note' && message['media_url'] != null) {
          print('Preparing player controller for voice note: ${message['id']}');
          try {
            final controller = await _audioUtils.createPlayerController(message['media_url']);
            _playerControllers[message['id']] = controller;
          } catch (e) {
            print('Error preparing player controller for ${message['id']}: $e');
          }
        }
      }

      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      await supabase
          .from('unread_messages')
          .delete()
          .eq('user_id', user.id)
          .eq('conversation_id', widget.conversationId);
    } catch (e) {
      print('Error fetching messages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupRealtimeSubscription() {
    final supabase = Supabase.instance.client;
    _channel = supabase.channel('messages:${widget.conversationId}');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversationId,
          ),
          callback: (payload) async {
            final newMessage = payload.newRecord;
            print('New message received via subscription: $newMessage');
            final senderData = await supabase
                .from('users')
                .select('username, profile_image_url')
                .eq('id', newMessage['sender_id'])
                .single();
            print('Sender data for new message: $senderData');
            setState(() {
              _messages.add({
                ...newMessage,
                'users': senderData,
              });
            });

            if (newMessage['media_type'] == 'voice_note' && newMessage['media_url'] != null) {
              print('Preparing player controller for new voice note: ${newMessage['id']}');
              try {
                final controller = await _audioUtils.createPlayerController(newMessage['media_url']);
                _playerControllers[newMessage['id']] = controller;
              } catch (e) {
                print('Error preparing player controller for new voice note: $e');
              }
            }

            final members = await supabase
                .from('conversation_members')
                .select('user_id')
                .eq('conversation_id', widget.conversationId);
            final user = supabase.auth.currentUser;
            if (user != null) {
              final otherMembers = members
                  .where((m) => m['user_id'] != user.id)
                  .map((m) => m['user_id'])
                  .toList();
              for (var memberId in otherMembers) {
                await supabase.from('unread_messages').insert({
                  'user_id': memberId,
                  'conversation_id': widget.conversationId,
                  'message_id': newMessage['id'],
                });
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) {
      print('Message is empty, not sending.');
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      print('User is not authenticated. Cannot send message.');
      return;
    }

    try {
      print('Attempting to send message: ${_messageController.text.trim()}');
      final message = {
        'id': const Uuid().v4(),
        'conversation_id': widget.conversationId,
        'sender_id': user.id,
        'content': _messageController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      };

      print('Inserting message into Supabase: $message');
      final response = await supabase.from('messages').insert(message).select();
      print('Message insert response: $response');

      print('Updating conversation updated_at');
      final updateResponse = await supabase
          .from('conversations')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', widget.conversationId)
          .select();
      print('Conversation update response: $updateResponse');

      _messageController.clear();
      print('Message sent successfully.');
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  Future<void> _pickMedia(String mediaType) async {
    try {
      File? file;
      if (mediaType == 'image') {
        final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (pickedFile != null) {
          file = File(pickedFile.path);
        }
      } else if (mediaType == 'video') {
        final pickedFile = await ImagePicker().pickVideo(source: ImageSource.gallery);
        if (pickedFile != null) {
          file = File(pickedFile.path);
        }
      } else {
        final result = await FilePicker.platform.pickFiles();
        if (result != null && result.files.single.path != null) {
          file = File(result.files.single.path!);
        }
      }

      if (file == null) {
        print('No file selected for upload.');
        return;
      }

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('User is not authenticated. Cannot upload media.');
        return;
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final filePath = 'chat_media/$fileName';

      print('Uploading file to Supabase: $filePath');
      final uploadResponse = await supabase.storage.from('chat_media').upload(filePath, file);
      print('Upload response: $uploadResponse');

      final mediaUrl = supabase.storage.from('chat_media').getPublicUrl(filePath);
      print('Media URL: $mediaUrl');

      final message = {
        'id': const Uuid().v4(),
        'conversation_id': widget.conversationId,
        'sender_id': user.id,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'created_at': DateTime.now().toIso8601String(),
      };

      print('Inserting media message: $message');
      await supabase.from('messages').insert(message);

      print('Updating conversation updated_at for media message');
      await supabase
          .from('conversations')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', widget.conversationId);
    } catch (e) {
      print('Error uploading media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading media: $e')),
        );
      }
    }
  }

  Future<void> _recordVoiceNote() async {
    try {
      if (_isRecording) {
        print('Stopping recording...');
        final path = await _audioUtils.stopRecording();
        if (path == null) {
          print('No recording path returned after stopping.');
          return;
        }

        print('Recording stopped. Path: $path');
        final file = File(path);
        if (!file.existsSync()) {
          print('Recording file does not exist at path: $path');
          return;
        }

        final supabase = Supabase.instance.client;
        final user = supabase.auth.currentUser;
        if (user == null) {
          print('User is not authenticated. Cannot upload voice note.');
          return;
        }

        final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        final filePath = 'chat_media/$fileName';

        print('Uploading voice note to Supabase: $filePath');
        final uploadResponse = await supabase.storage.from('chat_media').upload(filePath, file);
        print('Voice note upload response: $uploadResponse');

        final mediaUrl = supabase.storage.from('chat_media').getPublicUrl(filePath);
        print('Voice note URL: $mediaUrl');

        final message = {
          'id': const Uuid().v4(),
          'conversation_id': widget.conversationId,
          'sender_id': user.id,
          'media_url': mediaUrl,
          'media_type': 'voice_note',
          'created_at': DateTime.now().toIso8601String(),
        };

        print('Inserting voice note message: $message');
        await supabase.from('messages').insert(message);

        print('Updating conversation updated_at for voice note');
        await supabase
            .from('conversations')
            .update({'updated_at': DateTime.now().toIso8601String()})
            .eq('id', widget.conversationId);

        setState(() {
          _isRecording = false;
        });
        print('Voice note sent successfully.');
      } else {
        print('Starting recording...');
        final path = await _audioUtils.startRecording();
        if (path == null) {
          print('Failed to start recording: Permission denied or error.');
          return;
        }
        print('Recording started. Path: $path');
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      print('Error recording voice note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording voice note: $e')),
        );
      }
      setState(() {
        _isRecording = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_conversation == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF4CAF50),
          ),
        ),
      );
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('User not logged in'),
        ),
      );
    }

    final Map<String, List<Map<String, dynamic>>> messagesByDate = {};
    for (var message in _messages) {
      final date = DateTime.parse(message['created_at']).toLocal();
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      if (!messagesByDate.containsKey(dateKey)) {
        messagesByDate[dateKey] = [];
      }
      messagesByDate[dateKey]!.add(message);
    }

    final List<Widget> messageWidgets = [];
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    messagesByDate.forEach((dateKey, messages) {
      final dividerText = dateKey == today ? 'Today' : DateFormat('MMMM d, yyyy').format(DateTime.parse(dateKey));
      messageWidgets.add(
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              dividerText,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      );

      for (var message in messages) {
        final isMe = message['sender_id'] == user.id;
        final senderUsername = message['users']['username'] ?? 'Unknown';
        final senderProfileImage = message['users']['profile_image_url'];

        messageWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundImage: senderProfileImage != null
                          ? CachedNetworkImageProvider(senderProfileImage)
                          : null,
                      child: senderProfileImage == null
                          ? const Icon(Icons.person, color: Colors.white, size: 16)
                          : null,
                    ),
                  ),
                Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          senderUsername,
                          style: const TextStyle(
                            color: Color(0xFFB3B3B3),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF4CAF50) : Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: message['media_type'] != null
                          ? _buildMediaWidget(message['media_url'], message['media_type'], message['id'])
                          : Text(
                              message['content'] ?? '',
                              style: const TextStyle(color: Colors.white),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        DateFormat('h:mm a').format(DateTime.parse(message['created_at']).toLocal()),
                        style: const TextStyle(
                          color: Color(0xFFB3B3B3),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            context.pop();
          },
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: _conversation!['profile_image_url'] != null
                  ? CachedNetworkImageProvider(_conversation!['profile_image_url'])
                  : null,
              child: _conversation!['profile_image_url'] == null
                  ? const Icon(Icons.group, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              _conversation!['name'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: () {
              // Implement video call functionality
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF4CAF50),
                    ),
                  )
                : messageWidgets.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages yet. Start the conversation!',
                          style: TextStyle(color: Color(0xFFB3B3B3)),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(top: 16, bottom: 16),
                        children: messageWidgets,
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add, color: Color(0xFF4CAF50)),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: const Color(0xFF1E1E1E),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      builder: (context) {
                        return SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.image, color: Colors.white),
                                title: const Text('Image', style: TextStyle(color: Colors.white)),
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickMedia('image');
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.videocam, color: Colors.white),
                                title: const Text('Video', style: TextStyle(color: Colors.white)),
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickMedia('video');
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.insert_drive_file, color: Colors.white),
                                title: const Text('File', style: TextStyle(color: Colors.white)),
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickMedia('file');
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message here...',
                      hintStyle: const TextStyle(color: Color(0xFFB3B3B3)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    style: const TextStyle(color: Colors.black),
                    onSubmitted: (value) {
                      _sendMessage();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _messageController.text.trim().isEmpty
                    ? IconButton(
                        icon: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: _isRecording ? Colors.red : const Color(0xFF4CAF50),
                        ),
                        onPressed: _recordVoiceNote,
                      )
                    : IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFF4CAF50)),
                        onPressed: _sendMessage,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaWidget(String mediaUrl, String mediaType, String messageId) {
    if (mediaType == 'image') {
      return Image.network(
        mediaUrl,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Text(
            'Error loading image',
            style: TextStyle(color: Colors.red),
          );
        },
      );
    } else if (mediaType == 'video') {
      return Column(
        children: [
          const Icon(
            Icons.videocam,
            color: Colors.white,
            size: 50,
          ),
          TextButton(
            onPressed: () {
              // Implement video playback
            },
            child: const Text(
              'Play Video',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      );
    } else if (mediaType == 'voice_note') {
      final controller = _playerControllers[messageId];
      if (controller == null) {
        return const Text(
          'Error loading voice note',
          style: TextStyle(color: Colors.red),
        );
      }
      return Row(
        children: [
          IconButton(
            icon: Icon(
              _audioUtils.currentlyPlayingId == messageId ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: () {
              if (_audioUtils.currentlyPlayingId == messageId) {
                _audioUtils.pauseAudio();
              } else {
                _audioUtils.playAudio(messageId, mediaUrl);
              }
            },
          ),
          Expanded(
            child: AudioFileWaveforms(
              size: const Size(double.infinity, 50),
              playerController: controller,
              enableSeekGesture: true,
              waveformType: WaveformType.long,
              playerWaveStyle: const PlayerWaveStyle(
                scaleFactor: 100,
                waveThickness: 2,
                showSeekLine: true,
              ),
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          const Icon(
            Icons.insert_drive_file,
            color: Colors.white,
            size: 50,
          ),
          TextButton(
            onPressed: () {
              // Implement file download/view
            },
            child: const Text(
              'View File',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      );
    }
  }
}