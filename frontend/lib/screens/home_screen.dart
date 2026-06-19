import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../utils/file_picker_helper.dart';
import '../utils/audio_recorder_helper.dart';
import '../utils/audio_player_helper.dart';
import '../utils/file_downloader_helper.dart';
import '../utils/video_preview_helper.dart';
import '../utils/location_helper.dart';
import '../utils/launcher_helper.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'notice_board_screen.dart';
import 'events_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _authService = AuthService();
  final _chatService = ChatService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _recorder = getAudioRecorder();

  String? _username;
  String? _currentUserId;
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollingTimer;
  Timer? _liveLocationTimer;

  // Audio Recording states
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;

  // Mic pulse animation while recording
  late AnimationController _micPulseController;

  // Send button morph animation (mic <-> send)
  late AnimationController _sendButtonController;

  // Tracks audio playing state for voice note play/pause animations
  final Map<String, bool> _playingAudio = {};

  // Track ids that have already been animated in, so we don't replay
  // entrance animations every time the list rebuilds from polling.
  final Set<String> _animatedMessageIds = {};

  // Deterministic colors for member avatars
  final List<Color> _avatarColors = [
    Colors.teal.shade600,
    Colors.indigo.shade600,
    Colors.purple.shade600,
    Colors.pink.shade600,
    Colors.blueGrey.shade600,
    Colors.deepOrange.shade600,
    Colors.amber.shade800,
    Colors.cyan.shade700,
    Colors.red.shade600,
    Colors.green.shade700,
  ];

  bool _navBarVisible = false;   // hidden by default — chat mode
  double _lastScrollOffset = 0;
  Timer? _navBarTimer;           // auto-dismiss timer

  bool get _hasText => _messageController.text.trim().isNotEmpty;

  StreamSubscription? _newMessageSub;
  StreamSubscription? _reactionSub;
  StreamSubscription? _locationSub;

  @override
  void initState() {
    super.initState();
    _loadUserAndMessages();
    
    _chatService.connectSocket();
    
    _newMessageSub = _chatService.onNewMessage.listen((message) {
      if (!mounted) return;
      
      final isNewFromOther = message.senderId != _currentUserId && !_messages.any((m) => m.id == message.id);
      
      if (isNewFromOther) {
        NotificationService.instance.showMessageNotification(
          senderName: message.senderName,
          messagePreview: message.message.isNotEmpty
              ? message.message
              : message.file != null
                  ? '📎 Sent an attachment'
                  : '',
        );
      }
      
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == message.id);
        if (idx > -1) {
          _messages[idx] = message;
        } else {
          _messages.add(message);
        }
      });
      _scrollToBottom(animated: true);
    });

    _reactionSub = _chatService.onReactionUpdated.listen((data) {
      if (!mounted) return;
      final messageId = data['messageId'];
      final reactionsList = data['reactions'] as List<dynamic>? ?? [];
      final parsedReactions = reactionsList.map((r) => MessageReaction.fromJson(r as Map<String, dynamic>)).toList();
      
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx > -1) {
          final old = _messages[idx];
          _messages[idx] = ChatMessage(
            id: old.id,
            senderId: old.senderId,
            senderName: old.senderName,
            message: old.message,
            createdAt: old.createdAt,
            senderProfilePic: old.senderProfilePic,
            file: old.file,
            location: old.location,
            reactions: parsedReactions,
          );
        }
      });
    });

    _locationSub = _chatService.onLocationUpdated.listen((data) {
      if (!mounted) return;
      final messageId = data['messageId'];
      final locData = data['location'];
      
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx > -1) {
          final old = _messages[idx];
          _messages[idx] = ChatMessage(
            id: old.id,
            senderId: old.senderId,
            senderName: old.senderName,
            message: old.message,
            createdAt: old.createdAt,
            senderProfilePic: old.senderProfilePic,
            file: old.file,
            location: ChatLocation.fromJson(locData as Map<String, dynamic>),
            reactions: old.reactions,
          );
        }
      });
    });

    // Live Location updates sync every 20 seconds
    _liveLocationTimer = Timer.periodic(const Duration(seconds: 20), (_) => _updateMyLiveLocations());

    // Hide nav bar when scrolling down (chatting); reveal on scroll-up
    _scrollController.addListener(_onScroll);

    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _sendButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    // Text controller typing updates
    _messageController.addListener(() {
      if (!mounted) return;
      if (_hasText && _sendButtonController.value == 0) {
        _sendButtonController.forward();
      } else if (!_hasText && _sendButtonController.value == 1) {
        _sendButtonController.reverse();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _newMessageSub?.cancel();
    _reactionSub?.cancel();
    _locationSub?.cancel();
    _chatService.disconnectSocket();
    
    _recordTimer?.cancel();
    _liveLocationTimer?.cancel();
    _navBarTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    _micPulseController.dispose();
    _sendButtonController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final offset = pos.pixels;
    final maxExtent = pos.maxScrollExtent;

    // At or near bottom → always HIDE nav (user is in chat/typing mode)
    if (maxExtent - offset < 80) {
      if (_navBarVisible) {
        _navBarTimer?.cancel();
        setState(() => _navBarVisible = false);
      }
      _lastScrollOffset = offset;
      return;
    }

    final delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;

    // Scrolling UP (to older messages) → keep nav hidden
    if (delta < -5 && _navBarVisible) {
      _navBarTimer?.cancel();
      setState(() => _navBarVisible = false);
    }
    // Scrolling DOWN (returning toward newer messages) → keep hidden too;
    // nav only appears via the overscroll pull-down gesture (handled in ListView wrapper)
  }

  /// Called when the user performs a hard pull-down at the bottom of the chat.
  /// Shows the nav bar and auto-dismisses it after 5 seconds.
  void _showNavBarTemporarily() {
    _navBarTimer?.cancel();
    if (!_navBarVisible) setState(() => _navBarVisible = true);
    _navBarTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _navBarVisible) setState(() => _navBarVisible = false);
    });
  }

  Future<void> _updateMyLiveLocations() async {
    final now = DateTime.now();
    // Add a 30-second buffer so we stop syncing before the server rejects it.
    final activeLiveLocs = _messages.where((msg) {
      return msg.senderId == _currentUserId &&
             msg.location != null &&
             msg.location!.isLive &&
             msg.location!.liveExpiresAt != null &&
             msg.location!.liveExpiresAt!.isAfter(now.add(const Duration(seconds: 30)));
    }).toList();

    if (activeLiveLocs.isEmpty) return;

    try {
      final pos = await getCurrentLocation();
      final lat = pos['latitude']!;
      final lng = pos['longitude']!;

      for (var msg in activeLiveLocs) {
        try {
          await _chatService.updateLiveLocation(msg.id, lat, lng);
        } catch (_) {
          // Silently skip individual messages that fail (e.g. already expired on server).
        }
      }
    } catch (e) {
      // Location permission denied or unavailable — don't spam the log.
      debugPrint('Live location sync skipped: $e');
    }
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AnimatedSheet(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 16),
                    child: Text(
                      'Share Location',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  _SheetTile(
                    color: Colors.green,
                    icon: Icons.my_location_rounded,
                    title: 'Share Current Location',
                    subtitle: 'Send your exact coordinate once',
                    onTap: () {
                      Navigator.of(context).pop();
                      _shareCurrentLocation();
                    },
                  ),
                  const SizedBox(height: 8),
                  _SheetTile(
                    color: Colors.blue,
                    icon: Icons.location_searching_rounded,
                    title: 'Share Live Location...',
                    subtitle: 'Update coordinate in real-time',
                    onTap: () {
                      Navigator.of(context).pop();
                      _showLiveDurationDialog();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLiveDurationDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Live location duration',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return Transform.scale(
          scale: 0.85 + (0.15 * curved.value).clamp(0.0, 0.15),
          child: Opacity(
            opacity: animation.value.clamp(0.0, 1.0),
            child: Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share Live Location For',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _DurationOption(
                      label: '1 Hour',
                      icon: Icons.timer_outlined,
                      onTap: () {
                        Navigator.of(context).pop();
                        _shareLiveLocation(1);
                      },
                    ),
                    _DurationOption(
                      label: '4 Hours',
                      icon: Icons.timer_outlined,
                      onTap: () {
                        Navigator.of(context).pop();
                        _shareLiveLocation(4);
                      },
                    ),
                    _DurationOption(
                      label: '8 Hours',
                      icon: Icons.timer_outlined,
                      onTap: () {
                        Navigator.of(context).pop();
                        _shareLiveLocation(8);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareCurrentLocation() async {
    setState(() => _isSending = true);
    try {
      final pos = await getCurrentLocation();
      final sentMsg = await _chatService.sendMessage(
        "",
        location: ChatLocation(
          latitude: pos['latitude']!,
          longitude: pos['longitude']!,
          isLive: false,
        ),
      );
      if (mounted) {
        setState(() {
          _messages.add(sentMsg);
          _isSending = false;
        });
        _scrollToBottom(animated: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _showErrorSnack('Failed to share current location: $e');
      }
    }
  }

  Future<void> _shareLiveLocation(int hours) async {
    setState(() => _isSending = true);
    try {
      final pos = await getCurrentLocation();
      final expiryTime = DateTime.now().add(Duration(hours: hours));
      final sentMsg = await _chatService.sendMessage(
        "",
        location: ChatLocation(
          latitude: pos['latitude']!,
          longitude: pos['longitude']!,
          isLive: true,
          liveExpiresAt: expiryTime,
        ),
      );
      if (mounted) {
        setState(() {
          _messages.add(sentMsg);
          _isSending = false;
        });
        _scrollToBottom(animated: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _showErrorSnack('Failed to share live location: $e');
      }
    }
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _showMediaPreview(BuildContext context, ChatFile file) {
    showGeneralDialog(
      context: context,
      barrierLabel: 'Media preview',
      barrierColor: Colors.black.withValues(alpha: 0.9),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: Hero(
                        tag: 'media_${file.data.hashCode}',
                        child: InteractiveViewer(
                          child: file.type == 'image'
                              ? _buildFullImage(file.data)
                              : buildFullVideoPlayer(file.data),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    left: 20,
                    child: _CircleIconButton(
                      icon: Icons.close,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    right: 20,
                    child: _CircleIconButton(
                      icon: Icons.download_rounded,
                      onTap: () => downloadOrOpenFile(file),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFullImage(String data) {
    try {
      final base64Data = data.split(',')[1];
      final bytes = base64Decode(base64Data);
      return Image.memory(bytes, fit: BoxFit.contain);
    } catch (e) {
      return const Text('Error loading preview', style: TextStyle(color: Colors.white));
    }
  }

  Widget _buildLocationWidget(ChatLocation location, bool isMe, ThemeData theme) {
    final now = DateTime.now();
    final bool isExpired = location.isLive &&
                           location.liveExpiresAt != null &&
                           now.isAfter(location.liveExpiresAt!);

    String title = location.isLive ? 'Live Location' : 'Current Location';
    String subtitle = 'Coordinates: ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';

    if (location.isLive) {
      if (isExpired) {
        subtitle = 'Live location ended';
      } else {
        final remaining = location.liveExpiresAt!.difference(now);
        final hours = remaining.inHours;
        final minutes = remaining.inMinutes % 60;
        subtitle = 'Active: sharing for ${hours > 0 ? "$hours hr " : ""}$minutes min';
      }
    }

    final fgColor = isMe ? Colors.white : theme.colorScheme.onSurface;
    final fgColorMuted = isMe ? Colors.white70 : theme.colorScheme.onSurfaceVariant;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withValues(alpha: 0.14) : theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? Colors.white.withValues(alpha: 0.12) : theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: location.isLive
                        ? (isExpired ? Colors.grey : Colors.green.shade600)
                        : theme.colorScheme.primary,
                    child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                  ),
                  if (location.isLive && !isExpired)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: _PulsingDot(),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: fgColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: fgColorMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isMe ? Colors.white24 : theme.colorScheme.primaryContainer,
                foregroundColor: isMe ? Colors.white : theme.colorScheme.onPrimaryContainer,
                elevation: 0,
                minimumSize: const Size(double.infinity, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final url = 'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';
                launchUrlString(url);
              },
              icon: const Icon(Icons.map_outlined, size: 16),
              label: const Text('Open Maps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserAndMessages() async {
    final username = await _authService.getStoredUsername();
    final currentUserId = await _authService.getStoredUserId();
    if (mounted) {
      setState(() {
        _username = username;
        _currentUserId = currentUserId;
      });
    }
    await _fetchMessages(initial: true);
  }

  Future<void> _fetchMessages({bool initial = false}) async {
    try {
      final messages = await _chatService.fetchMessages();
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        if (initial) {
          _scrollToBottom(animated: false);
        }
      }
    } catch (e) {
      if (initial && mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Error fetching messages: $e');
    }
  }



  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      final sentMsg = await _chatService.sendMessage(text);
      if (mounted) {
        setState(() {
          _messages.add(sentMsg);
          _isSending = false;
        });
        _scrollToBottom(animated: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _showErrorSnack('Failed to send message: $e');
      }
    }
  }

  Future<void> _pickAttachment() async {
    try {
      final picked = await pickFileAttachment();
      if (picked == null) return;

      setState(() => _isSending = true);

      final sentMsg = await _chatService.sendMessage(
        "",
        file: ChatFile(
          data: picked.data,
          name: picked.name,
          type: picked.type,
        ),
      );

      if (mounted) {
        setState(() {
          _messages.add(sentMsg);
          _isSending = false;
        });
        _scrollToBottom(animated: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _showErrorSnack('Error uploading file: $e');
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      await _recorder.start();
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
      });
      _micPulseController.repeat();
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordDuration++;
        });
      });
    } catch (e) {
      _showErrorSnack('Recording error: $e');
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    _recordTimer?.cancel();
    _micPulseController.stop();
    _micPulseController.reset();
    final base64Audio = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _recordDuration = 0;
    });

    if (cancel || base64Audio == null) return;

    setState(() => _isSending = true);
    try {
      final sentMsg = await _chatService.sendMessage(
        "",
        file: ChatFile(
          data: base64Audio,
          name: 'Voice Message.webm',
          type: 'voice',
        ),
      );
      if (mounted) {
        setState(() {
          _messages.add(sentMsg);
          _isSending = false;
        });
        _scrollToBottom(animated: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _showErrorSnack('Error sending voice message: $e');
      }
    }
  }

  Future<void> _sendReaction(String messageId, String emoji) async {
    try {
      final updatedReactions = await _chatService.reactToMessage(messageId, emoji);
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx > -1) {
          final old = _messages[idx];
          _messages[idx] = ChatMessage(
            id: old.id,
            senderId: old.senderId,
            senderName: old.senderName,
            message: old.message,
            createdAt: old.createdAt,
            senderProfilePic: old.senderProfilePic,
            file: old.file,
            reactions: updatedReactions,
          );
        }
      });
    } catch (e) {
      _showErrorSnack('Failed to react: $e');
    }
  }

  void _showReactionsPopup(ChatMessage message) {
    showGeneralDialog(
      context: context,
      barrierLabel: 'Reactions',
      barrierColor: Colors.black.withValues(alpha: 0.15),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        final emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
        return Opacity(
          opacity: animation.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.6 + (0.4 * curved.value).clamp(0.0, 0.4),
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(emojis.length, (i) {
                    return _ReactionOption(
                      emoji: emojis[i],
                      delay: i * 35,
                      onTap: () {
                        Navigator.pop(context);
                        _sendReaction(message.id, emojis[i]);
                      },
                    );
                  }),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    _pollingTimer?.cancel();
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Color _getAvatarColor(String name) {
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final index = hash.abs() % _avatarColors.length;
    return _avatarColors[index];
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Widget _buildAvatar(String? profilePicData, Color avatarColor, String initials, {double radius = 18, double fontSize = 13}) {
    final hasPic = profilePicData != null && profilePicData.trim().isNotEmpty;
    if (hasPic) {
      final picString = profilePicData.trim();
      if (picString.startsWith('data:image/')) {
        try {
          final base64Data = picString.split(',')[1];
          final bytes = base64Decode(base64Data);
          return CircleAvatar(
            radius: radius,
            backgroundColor: avatarColor,
            backgroundImage: MemoryImage(bytes),
          );
        } catch (_) {}
      } else if (picString.startsWith('http://') || picString.startsWith('https://')) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: avatarColor,
          backgroundImage: NetworkImage(picString),
        );
      }
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: avatarColor,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic))
                .animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme      = Theme.of(context);
    final cs         = theme.colorScheme;
    final isDark     = theme.brightness == Brightness.dark;
    final displayName = _username ?? 'Family Member';
    final appState   = AppStateProvider.of(context);
    final bgColors   = AppState.chatBgPresets[appState.chatBgIndex];

    final String greeting;
    final hour = DateTime.now().hour;
    if (hour < 12)      greeting = 'Good morning,';
    else if (hour < 17) greeting = 'Good afternoon,';
    else                greeting = 'Good evening,';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF111020) : const Color(0xFFF8F7FF),
      // extendBody is FALSE — body must not go under nav bar; they stack properly
      drawer: _buildDrawer(cs, displayName),

      // ── Bottom Navigation Bar ──────────────────────────────────────────
      // Uses SizeTransition → collapses to height=0 when hidden, so body
      // cleanly expands to fill the space (no gap, no overlap with composer).
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) => SizeTransition(
          sizeFactor: animation,
          axisAlignment: 1,
          child: child,
        ),
        child: _navBarVisible
            ? Container(
                key: const ValueKey('navBarVisible'),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1B2E) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _NavItem(icon: Icons.chat_bubble_rounded,     label: 'Chat',    active: true,  color: cs.primary,              onTap: () => setState(() => _navBarVisible = false)),
                        _NavItem(icon: Icons.notifications_rounded,   label: 'Notices', active: false, color: const Color(0xFFFF9800), onTap: () => _navigateTo(const NoticeBoardScreen())),
                        _NavItem(icon: Icons.event_rounded,           label: 'Events',  active: false, color: const Color(0xFFEC407A), onTap: () => _navigateTo(const EventsScreen())),
                        _NavItem(icon: Icons.settings_rounded,        label: 'Settings',active: false, color: const Color(0xFF78909C), onTap: () => _navigateTo(const SettingsScreen())),
                        _NavItem(icon: Icons.account_circle_rounded,  label: 'Profile', active: false, color: const Color(0xFF26A69A), onTap: () => Navigator.of(context).push(PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 280),
                          pageBuilder: (_, __, ___) => const ProfileScreen(),
                          transitionsBuilder: (_, a, __, child) => SlideTransition(
                            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                                .chain(CurveTween(curve: Curves.easeOutCubic)).animate(a),
                            child: child,
                          ),
                        )).then((_) => _loadUserAndMessages())),
                      ],
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('navBarHidden')),
      ),

      // ── Body ──────────────────────────────────────────────────────────
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            color: isDark ? const Color(0xFF1C1B2E) : Colors.white,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 20, right: 12, bottom: 14,
            ),
            child: Row(
              children: [
                // Hamburger
                GestureDetector(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A2740) : const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.menu_rounded, color: cs.primary, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                // Greeting
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(greeting,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.grey.shade500,
                          fontWeight: FontWeight.w400,
                        )),
                      Text(displayName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                          letterSpacing: -0.5,
                        )),
                    ],
                  ),
                ),
                // Bell
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(Icons.notifications_outlined,
                        color: isDark ? Colors.white70 : const Color(0xFF1A1A2E), size: 26),
                      onPressed: () => _navigateTo(const NoticeBoardScreen()),
                    ),
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(color: Color(0xFFEF5350), shape: BoxShape.circle),
                      ),
                    ),
                  ],
                ),
                // Profile avatar
                GestureDetector(
                  onTap: () => Navigator.of(context).push(PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 280),
                    pageBuilder: (_, __, ___) => const ProfileScreen(),
                    transitionsBuilder: (_, a, __, child) => SlideTransition(
                      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                          .chain(CurveTween(curve: Curves.easeOutCubic)).animate(a),
                      child: child,
                    ),
                  )).then((_) => _loadUserAndMessages()),
                  child: Container(
                    width: 38, height: 38,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.secondary],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Subtle divider
          Divider(height: 1, thickness: 1, color: isDark ? Colors.white10 : Colors.grey.shade100),

          // ── Chat area ────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: bgColors,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: _isLoading
                  ? const _LoadingState()
                  : _messages.isEmpty
                      ? _buildEmptyState(theme)
                      // NotificationListener catches overscroll (pull-down past bottom)
                      // → that's the user's signal to show the nav bar
                      : NotificationListener<OverscrollNotification>(
                          onNotification: (n) {
                            // overscroll < 0 means pulled past the end (bottom)
                            if (n.overscroll < -30) _showNavBarTemporarily();
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final isMe = message.senderId == _currentUserId ||
                                           (message.senderName.toLowerCase() == _username?.toLowerCase());
                              final isNew = !_animatedMessageIds.contains(message.id);
                              _animatedMessageIds.add(message.id);
                              final row = _buildMessageRow(message, isMe, theme);
                              if (!isNew) return row;
                              return _AnimatedMessageEntry(isMe: isMe, child: row);
                            },
                          ),
                        ),
            ),
          ),

          // ── Progress bar ─────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _isSending
                ? LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: cs.primaryContainer,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  )
                : const SizedBox(height: 0, width: double.infinity),
          ),

          // ── Input area ───────────────────────────────────────────────
          _buildInputArea(theme),
        ],
      ),
    );
  }


  Widget _buildDrawer(ColorScheme cs, String displayName) {
    return Drawer(
      child: Column(
        children: [
          // ── Drawer Header ───────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                  ),
                  child: const Icon(Icons.family_restroom_rounded, color: Colors.white, size: 34),
                  // child: const Image(Icons.)
                ),
                const SizedBox(height: 14),
                const Text(
                  'Padmamangal',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.4),
                ),
                const SizedBox(height: 2),
                Text(
                  displayName,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),

          // ── Nav Items ────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              children: [
                _DrawerNavItem(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  color: cs.primary,
                  isActive: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 4),
                _DrawerNavItem(
                  icon: Icons.notifications_rounded,
                  label: 'Notice Board',
                  color: Colors.orange.shade600,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateTo(const NoticeBoardScreen());
                  },
                ),
                const SizedBox(height: 4),
                _DrawerNavItem(
                  icon: Icons.event_rounded,
                  label: 'Events & Reminders',
                  color: Colors.pink.shade500,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateTo(const EventsScreen());
                  },
                ),
                const SizedBox(height: 4),
                _DrawerNavItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  color: Colors.blueGrey.shade600,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateTo(const SettingsScreen());
                  },
                ),
                const Divider(height: 28, indent: 12, endIndent: 12),
                _DrawerNavItem(
                  icon: Icons.account_circle_outlined,
                  label: 'My Profile',
                  color: Colors.teal.shade600,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 280),
                        pageBuilder: (_, __, ___) => const ProfileScreen(),
                        transitionsBuilder: (ctx, animation, __, child) => SlideTransition(
                          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                              .chain(CurveTween(curve: Curves.easeOutCubic))
                              .animate(animation),
                          child: child,
                        ),
                      ),
                    ).then((_) => _loadUserAndMessages());
                  },
                ),
              ],
            ),
          ),

          // ── Footer ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            child: Material(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _logout,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.red.shade600),
                      const SizedBox(width: 14),
                      Text('Sign Out',
                        style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 20),
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 56,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No messages yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start the conversation by sending\nthe first message!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageRow(ChatMessage message, bool isMe, ThemeData theme) {
    final avatarColor = _getAvatarColor(message.senderName);
    final initials = _getInitials(message.senderName);
    final formattedTime = _formatTime(message.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _buildAvatar(message.senderProfilePic, avatarColor, initials),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showReactionsPopup(message),
              child: AnimatedScale(
                scale: 1.0,
                duration: const Duration(milliseconds: 120),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(left: 6, bottom: 2),
                        child: Text(
                          message.senderName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: avatarColor,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isMe
                            ? LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.primary.withValues(alpha: 0.85),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isMe ? null : theme.colorScheme.surface,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isMe
                                ? theme.colorScheme.primary.withValues(alpha: 0.18)
                                : Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.file != null) ...[
                            _buildAttachmentWidget(message.file!, isMe, theme),
                            if (message.message.isNotEmpty) const SizedBox(height: 8),
                          ],
                          if (message.location != null) ...[
                            _buildLocationWidget(message.location!, isMe, theme),
                            if (message.message.isNotEmpty) const SizedBox(height: 8),
                          ],
                          if (message.message.isNotEmpty)
                            Text(
                              message.message,
                              style: TextStyle(
                                color: isMe ? Colors.white : theme.colorScheme.onSurface,
                                fontSize: 15,
                                height: 1.3,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                          child: Text(
                            formattedTime,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        if (message.reactions.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          _AnimatedReactionsBadge(
                            reactions: message.reactions,
                            theme: theme,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildAttachmentWidget(ChatFile file, bool isMe, ThemeData theme) {
    if (file.type == 'image') {
      try {
        final base64Data = file.data.split(',')[1];
        final bytes = base64Decode(base64Data);
        return GestureDetector(
          onTap: () => _showMediaPreview(context, file),
          child: Hero(
            tag: 'media_${file.data.hashCode}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                bytes,
                width: 220,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      } catch (e) {
        return const Text('[Corrupted Image]');
      }
    } else if (file.type == 'video') {
      return GestureDetector(
        onTap: () => _showMediaPreview(context, file),
        child: Hero(
          tag: 'media_${file.data.hashCode}',
          child: Container(
            width: 220,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe ? Colors.white.withValues(alpha: 0.15) : theme.colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.play_circle_fill_rounded,
                      color: isMe ? Colors.white : theme.colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isMe ? Colors.white : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Video Message',
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (file.type == 'voice') {
      return _VoiceMessageWidget(
        file: file,
        isMe: isMe,
        theme: theme,
        isPlaying: _playingAudio[file.data] ?? false,
        onToggle: () {
          final isPlaying = _playingAudio[file.data] ?? false;
          if (isPlaying) {
            setState(() {
              _playingAudio[file.data] = false;
            });
          } else {
            playAudioBase64(file.data);
            setState(() {
              _playingAudio[file.data] = true;
            });
            Timer(const Duration(seconds: 10), () {
              if (mounted && _playingAudio[file.data] == true) {
                setState(() {
                  _playingAudio[file.data] = false;
                });
              }
            });
          }
        },
      );
    } else {
      // General file (document)
      final ext = file.name.contains('.') ? file.name.split('.').last.toUpperCase() : 'FILE';

      Color extColor;
      switch (ext) {
        case 'PDF':
          extColor = Colors.red.shade700;
          break;
        case 'DOC':
        case 'DOCX':
          extColor = Colors.blue.shade700;
          break;
        case 'XLS':
        case 'XLSX':
          extColor = Colors.green.shade700;
          break;
        case 'PPT':
        case 'PPTX':
          extColor = Colors.orange.shade700;
          break;
        case 'ZIP':
        case 'RAR':
          extColor = Colors.amber.shade800;
          break;
        case 'TXT':
          extColor = Colors.grey.shade600;
          break;
        default:
          extColor = theme.colorScheme.secondary;
      }

      String fileSizeStr = 'Unknown size';
      if (file.data.isNotEmpty) {
        final base64Length = file.data.contains(',') ? file.data.split(',')[1].length : file.data.length;
        final sizeInBytes = (base64Length * 3) / 4;
        if (sizeInBytes > 1024 * 1024) {
          fileSizeStr = '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        } else if (sizeInBytes > 1024) {
          fileSizeStr = '${(sizeInBytes / 1024).toStringAsFixed(0)} KB';
        } else {
          fileSizeStr = '${sizeInBytes.toStringAsFixed(0)} B';
        }
      }

      return _FileAttachmentWidget(
        file: file,
        isMe: isMe,
        theme: theme,
        ext: ext,
        extColor: extColor,
        fileSizeStr: fileSizeStr,
        onTap: () => downloadOrOpenFile(file),
      );
    }
  }

  Widget _buildInputArea(ThemeData theme) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return SizeTransition(
          sizeFactor: animation,
          axis: Axis.vertical,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: _isRecording
          ? _buildRecordingBar(theme)
          : _buildComposer(theme),
    );
  }

  Widget _buildRecordingBar(ThemeData theme) {
    return SafeArea(
      key: const ValueKey('recording'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _micPulseController,
                builder: (context, child) {
                  final t = _micPulseController.value;
                  final scale = 1.0 + (0.3 * (t < 0.5 ? t * 2 : (1 - t) * 2));
                  return Transform.scale(
                    scale: scale,
                    child: Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                  );
                },
              ),
              const SizedBox(width: 10),
              Text(
                'Recording  ${_formatDuration(_recordDuration)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
                onPressed: () => _stopRecording(cancel: true),
                tooltip: 'Cancel recording',
              ),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  onPressed: () => _stopRecording(cancel: false),
                  tooltip: 'Send voice note',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(ThemeData theme) {
    final appState = AppStateProvider.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Scaffold handles safe-area via bottomNavigationBar; use fixed padding here
    const bottomPad = 12.0;

    return KeyboardListener(
      key: const ValueKey('composer'),
      focusNode: FocusNode(canRequestFocus: false),
      onKeyEvent: (event) {
        if (!appState.sendOnEnter) return;
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
            !HardwareKeyboard.instance.isShiftPressed &&
            !HardwareKeyboard.instance.isControlPressed &&
            _hasText && !_isSending) {
          _sendMessage();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPad),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1C1B2E).withValues(alpha: 0.96)
              : Colors.white.withValues(alpha: 0.97),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── Composer bubble ─────────────────────────────────────
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2A2740)
                      : const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : theme.colorScheme.primary.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Attach icon
                    Tooltip(
                      message: 'Attach file or photo',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _pickAttachment,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                          child: Icon(
                            Icons.add_circle_rounded,
                            size: 24,
                            color: theme.colorScheme.primary.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ),
                    // Location icon
                    Tooltip(
                      message: 'Share location',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _showLocationPicker,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
                          child: Icon(
                            Icons.location_on_outlined,
                            size: 22,
                            color: theme.colorScheme.primary.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Text field
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 5,
                        // onSubmitted handles mobile keyboard 'Send' action
                        onSubmitted: appState.sendOnEnter ? (_) => _sendMessage() : null,
                        textInputAction: appState.sendOnEnter
                            ? TextInputAction.send
                            : TextInputAction.newline,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 15,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Message your family...',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // ── Send / Mic button ────────────────────────────────────
            _SendOrMicButton(
              controller: _sendButtonController,
              isSending: _isSending,
              hasText: _hasText,
              onSend: _sendMessage,
              onRecord: _startRecording,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Supporting animated widgets
// ─────────────────────────────────────────────────────────────────────────

/// Slide + fade entrance for newly arrived messages.
class _AnimatedMessageEntry extends StatefulWidget {
  final Widget child;
  final bool isMe;
  const _AnimatedMessageEntry({required this.child, required this.isMe});

  @override
  State<_AnimatedMessageEntry> createState() => _AnimatedMessageEntryState();
}

class _AnimatedMessageEntryState extends State<_AnimatedMessageEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

/// Loading state with subtle shimmer-like placeholder bubbles.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading messages...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing red dot for live-location indicators.
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 0.8 + (0.4 * _controller.value);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

/// Animated bottom sheet wrapper with slide-up entrance.
class _AnimatedSheet extends StatelessWidget {
  final Widget child;
  const _AnimatedSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 40),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }
}

/// Bottom sheet tile with tap-scale feedback.
class _SheetTile extends StatefulWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_SheetTile> createState() => _SheetTileState();
}

class _SheetTileState extends State<_SheetTile> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: widget.color,
                child: Icon(widget.icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      widget.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Duration option for the live-location dialog with ripple.
class _DurationOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DurationOption({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular icon button for media preview overlay.
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 26),
        onPressed: onTap,
      ),
    );
  }
}

/// Single reaction emoji option with staggered pop-in.
class _ReactionOption extends StatefulWidget {
  final String emoji;
  final int delay;
  final VoidCallback onTap;

  const _ReactionOption({required this.emoji, required this.delay, required this.onTap});

  @override
  State<_ReactionOption> createState() => _ReactionOptionState();
}

class _ReactionOptionState extends State<_ReactionOption> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final entrance = Curves.easeOutBack.transform(_controller.value);
        return Transform.scale(
          scale: entrance * _scale,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _scale = 1.3),
            onTapUp: (_) => setState(() => _scale = 1.0),
            onTapCancel: () => setState(() => _scale = 1.0),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Text(widget.emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
        );
      },
    );
  }
}

/// Reactions badge with pop-in animation when it first appears.
class _AnimatedReactionsBadge extends StatelessWidget {
  final List<MessageReaction> reactions;
  final ThemeData theme;

  const _AnimatedReactionsBadge({required this.reactions, required this.theme});

  @override
  Widget build(BuildContext context) {
    final Map<String, int> counts = {};
    for (var r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: counts.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(right: 3.0),
              child: Text(
                '${entry.key}${entry.value > 1 ? " ${entry.value}" : ""}',
                style: const TextStyle(fontSize: 12),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Voice message bubble with animated waveform-like progress.
class _VoiceMessageWidget extends StatelessWidget {
  final ChatFile file;
  final bool isMe;
  final ThemeData theme;
  final bool isPlaying;
  final VoidCallback onToggle;

  const _VoiceMessageWidget({
    required this.file,
    required this.isMe,
    required this.theme,
    required this.isPlaying,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isMe ? Colors.white : theme.colorScheme.onSurface;
    final accent = isMe ? Colors.white : theme.colorScheme.primary;

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(
                isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                key: ValueKey(isPlaying),
                color: accent,
                size: 38,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice Message',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: fg),
                ),
                const SizedBox(height: 6),
                _VoiceWaveform(isPlaying: isPlaying, color: accent, trackColor: isMe ? Colors.white30 : Colors.black12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small animated waveform bars that bounce while playing.
class _VoiceWaveform extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final Color trackColor;

  const _VoiceWaveform({required this.isPlaying, required this.color, required this.trackColor});

  @override
  State<_VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<_VoiceWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _heights = [6, 12, 18, 10, 16, 8, 14, 6];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.isPlaying) _controller.repeat();
  }

  @override
  void didUpdateWidget(_VoiceWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          height: 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_heights.length, (i) {
              double h = _heights[i];
              if (widget.isPlaying) {
                final phase = (_controller.value * 2 * 3.1416) + (i * 0.7);
                h = _heights[i] * (0.6 + 0.4 * (0.5 + 0.5 * _sin(phase)));
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Container(
                  width: 3,
                  height: h,
                  decoration: BoxDecoration(
                    color: widget.isPlaying ? widget.color : widget.trackColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  double _sin(double x) {
    // Lightweight sine approximation without importing dart:math separately
    // (kept local to avoid extra import churn).
    return (x - (x * x * x) / 6 + (x * x * x * x * x) / 120);
  }
}

/// File attachment bubble with tap-scale feedback.
class _FileAttachmentWidget extends StatefulWidget {
  final ChatFile file;
  final bool isMe;
  final ThemeData theme;
  final String ext;
  final Color extColor;
  final String fileSizeStr;
  final VoidCallback onTap;

  const _FileAttachmentWidget({
    required this.file,
    required this.isMe,
    required this.theme,
    required this.ext,
    required this.extColor,
    required this.fileSizeStr,
    required this.onTap,
  });

  @override
  State<_FileAttachmentWidget> createState() => _FileAttachmentWidgetState();
}

class _FileAttachmentWidgetState extends State<_FileAttachmentWidget> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final theme = widget.theme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withValues(alpha: 0.15) : theme.colorScheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: widget.extColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.ext,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isMe ? Colors.white : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.fileSizeStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_circle_down_rounded,
                color: isMe ? Colors.white70 : theme.colorScheme.primary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}



/// Send / mic button that morphs between states with rotation + scale,
/// and shows a spinner while sending.
class _SendOrMicButton extends StatelessWidget {
  final AnimationController controller;
  final bool isSending;
  final bool hasText;
  final VoidCallback onSend;
  final VoidCallback onRecord;

  const _SendOrMicButton({
    required this.controller,
    required this.isSending,
    required this.hasText,
    required this.onSend,
    required this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showSend = hasText || isSending;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: isSending ? null : (showSend ? onSend : onRecord),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) {
                return RotationTransition(
                  turns: Tween<double>(begin: 0.75, end: 1.0).animate(animation),
                  child: ScaleTransition(scale: animation, child: child),
                );
              },
              child: isSending
                  ? const SizedBox(
                      key: ValueKey('spinner'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      showSend ? Icons.send_rounded : Icons.mic_rounded,
                      key: ValueKey(showSend),
                      color: Colors.white,
                      size: 22,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drawer Navigation Item
// ─────────────────────────────────────────────────────────────────────────────
class _DrawerNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _DrawerNavItem({
    required this.icon,
    required this.label,
    required this.color,
    this.isActive = false,
    required this.onTap,
  });

  @override
  State<_DrawerNavItem> createState() => _DrawerNavItemState();
}

class _DrawerNavItemState extends State<_DrawerNavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: widget.isActive
              ? widget.color.withValues(alpha: 0.12)
              : _pressed
                  ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: widget.isActive
              ? Border.all(color: widget.color.withValues(alpha: 0.25), width: 1)
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: widget.isActive ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: widget.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontWeight: widget.isActive ? FontWeight.bold : FontWeight.w500,
                  fontSize: 15,
                  color: widget.isActive
                      ? widget.color
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (widget.isActive)
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Nav Item
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: widget.active
              ? widget.color.withValues(alpha: 0.12)
              : _pressed
                  ? (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04))
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              child: Icon(
                widget.icon,
                color: widget.active
                    ? widget.color
                    : (isDark ? Colors.white38 : Colors.grey.shade400),
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: widget.active ? FontWeight.bold : FontWeight.normal,
                color: widget.active
                    ? widget.color
                    : (isDark ? Colors.white38 : Colors.grey.shade400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}