import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  const CallScreen({super.key, required this.callId});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late RtcEngine _engine;
  List<Map<String, dynamic>> _participants = [];
  bool _isLoading = true;
  bool _isLocked = false;
  bool _isAdmin = false;
  bool _isCameraOn = true;
  bool _isMicOn = true;
  bool _isSpeakerOn = true;

  @override
  void initState() {
    super.initState();
    _initializeAgora();
    _fetchCallData();
  }

  Future<void> _initializeAgora() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: 'YOUR_AGORA_APP_ID', // Replace with your Agora App ID from .env
    ));

    await _engine.enableVideo();
    await _engine.startPreview();

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print('Joined channel: ${connection.channelId}');
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print('User joined: $remoteUid');
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          print('User offline: $remoteUid');
        },
      ),
    );

    await _engine.joinChannel(
      token: '', // You'll need to generate a token server-side in production
      channelId: widget.callId,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  Future<void> _fetchCallData() async {
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
          .from('video_calls')
          .select()
          .eq('id', widget.callId)
          .single();

      final participants = (response['participants'] as List<dynamic>).cast<String>();
      final participantsData = await supabase
          .from('users')
          .select('username, profile_image_url')
          .inFilter('id', participants);

      setState(() {
        _participants = participantsData;
        _isLocked = response['is_locked'] as bool;
        _isAdmin = response['admin_id'] == user.id;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching call data: $e');
      if (mounted) {
        context.go('/home');
      }
    }
  }

  Future<void> _toggleLock() async {
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('video_calls')
          .update({'is_locked': !_isLocked})
          .eq('id', widget.callId);

      setState(() {
        _isLocked = !_isLocked;
      });
    } catch (e) {
      print('Error toggling lock: $e');
    }
  }

  Future<void> _leaveCall() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final callData = await supabase
          .from('video_calls')
          .select('participants, admin_id')
          .eq('id', widget.callId)
          .single();

      final participants = (callData['participants'] as List<dynamic>).cast<String>();
      final updatedParticipants = participants.where((id) => id != user.id).toList();

      if (updatedParticipants.isEmpty) {
        // Delete the call if no participants remain
        await supabase.from('video_calls').delete().eq('id', widget.callId);
      } else {
        // Update participants
        await supabase
            .from('video_calls')
            .update({'participants': updatedParticipants})
            .eq('id', widget.callId);
      }

      await _engine.leaveChannel();
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      print('Error leaving call: $e');
    }
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4CAF50),
              ),
            )
          : SafeArea(
              child: Stack(
                children: [
                  GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    padding: const EdgeInsets.all(16),
                    itemCount: _participants.length,
                    itemBuilder: (context, index) {
                      final participant = _participants[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: participant['profile_image_url'] != null
                              ? Image.network(
                                  participant['profile_image_url'],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                )
                              : const Icon(
                                  Icons.person,
                                  color: Color(0xFFB3B3B3),
                                  size: 50,
                                ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: Icon(
                        _isLocked ? Icons.lock : Icons.lock_open,
                        color: _isAdmin ? Colors.white : Colors.grey,
                      ),
                      onPressed: _isAdmin ? _toggleLock : null,
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: _leaveCall,
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (_isAdmin)
                          IconButton(
                            icon: const Icon(Icons.person_add, color: Colors.white),
                            onPressed: () {
                              context.push('/add-friends/${widget.callId}');
                            },
                          ),
                        IconButton(
                          icon: Icon(
                            _isCameraOn ? Icons.videocam : Icons.videocam_off,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _isCameraOn = !_isCameraOn;
                            });
                            if (_isCameraOn) {
                              _engine.enableLocalVideo(true);
                            } else {
                              _engine.enableLocalVideo(false);
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            _isMicOn ? Icons.mic : Icons.mic_off,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _isMicOn = !_isMicOn;
                            });
                            if (_isMicOn) {
                              _engine.enableLocalAudio(true);
                            } else {
                              _engine.enableLocalAudio(false);
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _isSpeakerOn = !_isSpeakerOn;
                            });
                            _engine.setEnableSpeakerphone(_isSpeakerOn);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}