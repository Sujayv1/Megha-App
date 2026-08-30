import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/voice_assistant_service.dart';

/// Isolated, fluid-glassmorphic Microphone Button with pulsing wave ripple animations
/// for Speech-to-Text voice dictation.
class VoiceMicButton extends StatefulWidget {
  final TextEditingController textController;
  final VoidCallback? onSpeechCompleted;

  const VoiceMicButton({
    super.key,
    required this.textController,
    this.onSpeechCompleted,
  });

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _rippleAnimation;

  final VoiceAssistantService _voiceService = VoiceAssistantService.instance;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutSine,
      ),
    );

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOutQuad,
      ),
    );

    _pulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        if (_voiceService.isListening.value) {
          _pulseController.forward();
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _baseTextBeforeListening = '';

  Future<void> _toggleListening() async {
    HapticFeedback.lightImpact();

    if (_voiceService.isListening.value) {
      await _voiceService.stopListening();
      _pulseController.stop();
      _pulseController.reset();
      widget.onSpeechCompleted?.call();
    } else {
      // Capture any existing text in the input box so it is preserved and appended
      _baseTextBeforeListening = widget.textController.text;

      final started = await _voiceService.startListening(
        onResult: (String cumulativeSpeech) {
          if (mounted && cumulativeSpeech.isNotEmpty) {
            final base = _baseTextBeforeListening.trim();
            final combined = base.isEmpty
                ? cumulativeSpeech
                : '$base $cumulativeSpeech';
            widget.textController.value = TextEditingValue(
              text: combined,
              selection: TextSelection.collapsed(offset: combined.length),
            );
            widget.onSpeechCompleted?.call();
          }
        },
        onStatusChange: (bool listening) {
          if (mounted) {
            if (listening) {
              if (!_pulseController.isAnimating) {
                _pulseController.forward();
              }
            } else {
              _pulseController.stop();
              _pulseController.reset();
              widget.onSpeechCompleted?.call();
            }
          }
        },
      );

      if (started) {
        _pulseController.forward();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Microphone permission required for voice dictation'),
            backgroundColor: AppColors.textPrimary,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _voiceService.isListening,
      builder: (context, isListening, _) {
        return GestureDetector(
          onTap: _toggleListening,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return SizedBox(
                width: 38,
                height: 38,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer fluid ripple wave when listening
                    if (isListening)
                      CustomPaint(
                        painter: _MicRipplePainter(
                          progress: _rippleAnimation.value,
                          color: AppColors.leafGreen,
                        ),
                        child: const SizedBox(width: 38, height: 38),
                      ),
                    // Core glassmorphic mic button
                    Transform.scale(
                      scale: isListening ? _scaleAnimation.value : 1.0,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isListening
                              ? AppColors.leafGreen
                              : Colors.white.withValues(alpha: 0.85),
                          border: Border.all(
                            color: isListening
                                ? AppColors.leafGreen
                                : AppColors.leafGreen.withValues(alpha: 0.28),
                            width: isListening ? 1.5 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isListening
                                  ? AppColors.leafGreen.withValues(alpha: 0.38)
                                  : AppColors.leafGreen.withValues(alpha: 0.08),
                              blurRadius: isListening ? 10 : 5,
                              spreadRadius: isListening ? 2 : 0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          isListening
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          color: isListening
                              ? Colors.white
                              : AppColors.leafGreen,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Custom Painter for animated concentric expanding ripples
class _MicRipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  const _MicRipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // First expanding wave
    final radius1 = 20 + (maxRadius - 20) * progress;
    final opacity1 = (1.0 - progress).clamp(0.0, 1.0) * 0.35;
    final paint1 = Paint()
      ..color = color.withValues(alpha: opacity1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius1, paint1);

    // Second delayed expanding wave
    final progress2 = (progress + 0.5) % 1.0;
    final radius2 = 20 + (maxRadius - 20) * progress2;
    final opacity2 = (1.0 - progress2).clamp(0.0, 1.0) * 0.22;
    final paint2 = Paint()
      ..color = color.withValues(alpha: opacity2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius2, paint2);
  }

  @override
  bool shouldRepaint(_MicRipplePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
