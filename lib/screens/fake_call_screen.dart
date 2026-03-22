import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:my_contacts/theme/my_contacts_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:my_contacts/services/contacts_repository.dart';
import 'package:my_contacts/widgets/contact_avatar.dart';

/// A realistic fake incoming/outgoing call screen with ringing animation,
/// accept/decline buttons, and an in-call UI with mute/speaker/keypad controls.
class FakeCallScreen extends StatefulWidget {
  final Contact contact;
  final String phoneNumber;
  final bool autoAttend;
  final String? ringtonePath;

  const FakeCallScreen({
    super.key,
    required this.contact,
    required this.phoneNumber,
    required this.autoAttend,
    this.ringtonePath,
  });

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

enum _CallState { ringing, connected, ended }

class _FakeCallScreenState extends State<FakeCallScreen>
    with TickerProviderStateMixin {
  _CallState _callState = _CallState.ringing;
  Timer? _autoAnswerTimer;
  Timer? _callTimer;
  int _callSeconds = 0;
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isHeld = false;
  AudioPlayer? _ringtonePlayer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _slideUpController;
  late Animation<Offset> _slideUpAnimation;

  @override
  void initState() {
    super.initState();
    // Immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Pulse ring animation for ringing state
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Slide-up animation for the in-call controls
    _slideUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideUpAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideUpController,
            curve: Curves.easeOutCubic,
          ),
        );

    if (widget.autoAttend) {
      // Auto-answer after 3-6 seconds to simulate a real call.
      final delay = 3 + Random().nextInt(4);
      _autoAnswerTimer = Timer(Duration(seconds: delay), () {
        if (mounted && _callState == _CallState.ringing) {
          _answerCall();
        }
      });
    }

    _startRingtone();
  }

  Future<void> _startRingtone() async {
    final path = widget.ringtonePath;
    if (path == null) return;
    final player = AudioPlayer();
    _ringtonePlayer = player;
    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(DeviceFileSource(path));
    } catch (_) {
      // Silently ignore missing/unplayable file
    }
  }

  void _stopRingtone() {
    _ringtonePlayer?.stop();
    _ringtonePlayer?.dispose();
    _ringtonePlayer = null;
  }

  @override
  void dispose() {
    _stopRingtone();
    _autoAnswerTimer?.cancel();
    _callTimer?.cancel();
    _pulseController.dispose();
    _slideUpController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _answerCall() {
    HapticFeedback.mediumImpact();
    _stopRingtone();
    setState(() => _callState = _CallState.connected);
    _pulseController.stop();
    _slideUpController.forward();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callSeconds++);
    });
  }

  void _endCall() {
    HapticFeedback.heavyImpact();
    _stopRingtone();
    _callTimer?.cancel();
    _autoAnswerTimer?.cancel();
    setState(() => _callState = _CallState.ended);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  String get _formattedTime {
    final m = (_callSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_callSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _statusText => switch (_callState) {
    _CallState.ringing => 'Ringing...',
    _CallState.connected => _formattedTime,
    _CallState.ended => 'Call Ended',
  };

  @override
  Widget build(BuildContext context) {
    final repo = ContactsRepository();
    final highRes = repo.getHighResPhoto(widget.contact.id);
    final hasPhoto = widget.contact.photoOrThumbnail != null || highRes != null;

    return Scaffold(
      backgroundColor: MyContactsColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background — blurred photo or dark gradient
          if (hasPhoto)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Image.memory(
                highRes ?? widget.contact.photoOrThumbnail!,
                fit: BoxFit.cover,
                color: MyContactsColors.black.withValues(alpha: 0.5),
                colorBlendMode: BlendMode.darken,
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [MyContactsColors.cFF1A1A2E, MyContactsColors.cFF0F0F1A],
                ),
              ),
            ),

          // Dark overlay for contrast
          Container(color: MyContactsColors.black.withValues(alpha: 0.3)),

          // Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),

                // Status chip
                _buildStatusChip(),
                const SizedBox(height: 40),

                // Avatar with pulse animation
                _buildAvatar(),
                const SizedBox(height: 24),

                // Name
                Text(
                  widget.contact.displayName,
                  style: const TextStyle(
                    color: MyContactsColors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),

                // Phone number
                Text(
                  widget.phoneNumber,
                  style: TextStyle(
                    color: MyContactsColors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),

                // Status text
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _statusText,
                    key: ValueKey(_statusText),
                    style: TextStyle(
                      color: _callState == _CallState.connected
                          ? MyContactsColors.cFF4CAF50
                          : MyContactsColors.white.withValues(alpha: 0.6),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const Spacer(),

                // In-call controls (only when connected)
                if (_callState == _CallState.connected)
                  SlideTransition(
                    position: _slideUpAnimation,
                    child: _buildInCallControls(),
                  ),

                const SizedBox(height: 20),

                // Bottom action buttons
                _buildBottomActions(),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    final (icon, color, text) = switch (_callState) {
      _CallState.ringing => (
        Icons.ring_volume_rounded,
        MyContactsColors.cFF4CAF50,
        'Incoming Call',
      ),
      _CallState.connected => (
        Icons.phone_in_talk_rounded,
        MyContactsColors.cFF2196F3,
        'Connected',
      ),
      _CallState.ended => (Icons.call_end_rounded, MyContactsColors.red, 'Ended'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final avatarWidget = ContactAvatar(contact: widget.contact, radius: 60);

    if (_callState == _CallState.ringing) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: MyContactsColors.cFF4CAF50.withValues(
                      alpha: 0.3 * (_pulseAnimation.value - 1) * 6.67,
                    ),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }

  Widget _buildInCallControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _isMuted ? 'Unmute' : 'Mute',
            isActive: _isMuted,
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _isMuted = !_isMuted);
            },
          ),
          _buildControlButton(
            icon: Icons.dialpad_rounded,
            label: 'Keypad',
            onTap: () => HapticFeedback.lightImpact(),
          ),
          _buildControlButton(
            icon: _isSpeaker
                ? Icons.volume_up_rounded
                : Icons.volume_down_rounded,
            label: 'Speaker',
            isActive: _isSpeaker,
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _isSpeaker = !_isSpeaker);
            },
          ),
          _buildControlButton(
            icon: Icons.pause_rounded,
            label: _isHeld ? 'Resume' : 'Hold',
            isActive: _isHeld,
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _isHeld = !_isHeld);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive
                  ? MyContactsColors.white.withValues(alpha: 0.3)
                  : MyContactsColors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: MyContactsColors.white.withValues(alpha: isActive ? 0.5 : 0.15),
              ),
            ),
            child: Icon(icon, color: MyContactsColors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: MyContactsColors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    if (_callState == _CallState.ended) {
      return const SizedBox.shrink();
    }

    if (_callState == _CallState.ringing) {
      // Ringing: Decline (red) + Accept (green)
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 50),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildRoundButton(
              icon: Icons.call_end_rounded,
              color: MyContactsColors.red,
              label: 'Decline',
              onTap: _endCall,
            ),
            _buildRoundButton(
              icon: Icons.call_rounded,
              color: MyContactsColors.cFF4CAF50,
              label: 'Accept',
              onTap: _answerCall,
            ),
          ],
        ),
      );
    }

    // Connected: just the red end-call button
    return _buildRoundButton(
      icon: Icons.call_end_rounded,
      color: MyContactsColors.red,
      label: 'End Call',
      onTap: _endCall,
      size: 72,
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    double size = 64,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: MyContactsColors.white, size: size * 0.45),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: MyContactsColors.white.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
