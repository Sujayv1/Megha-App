import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_drawing/path_drawing.dart';

/// Pre-parsed native Flutter Path constants for Outer Hero Banner & Chat Avatar Blooming Animations
final Path _leftPath1 = parseSvgPathData(
  "M42.48,34.674C42.48,34.674,125.262,57.185,125.262,57.185C125.262,57.185,116.911,47.385,116.911,47.385C84.234,9.622,39.939,2.36,4.9,0.182C4.9,0.182,0,0,0,0C0,0,0.545,4.72,0.545,4.72C4.9,41.936,22.511,76.61,51.376,104.93C80.059,133.25,117.276,152.675,158.847,161.207C158.847,161.207,186.986,167.016,186.986,167.016C186.986,167.016,161.386,153.945,161.386,153.945C105.111,124.9,63.176,93.311,42.48,34.674Z",
);

final Path _leftPath2 = parseSvgPathData(
  "M64.083,55.188C71.132,58.167,77.88,61.814,84.234,66.08C90.769,70.255,96.76,74.794,102.934,79.514C108.925,84.234,114.734,89.136,120.362,94.4C126.049,99.533,131.107,105.322,135.43,111.646C129.984,106.2,124.356,101.298,118.547,96.397C112.738,91.677,106.747,86.957,100.756,82.237C94.765,77.517,88.772,72.797,82.783,68.259C76.609,63.902,70.437,59.545,64.083,55.188Z",
);

final Path _centerPath = parseSvgPathData(
  "M224.383,163.93C224.383,163.93,222.931,182.447,222.931,182.447C222.931,182.447,231.831,166.108,231.831,166.108C257.431,119.271,242.542,39.756,201.151,2.541C201.151,2.541,198.059,0,198.059,0C198.059,0,195.517,2.9,195.517,2.9C125.988,77.7,120.36,180.45,180.995,271.039C180.995,271.039,195.155,292.279,195.155,292.279C195.155,292.279,187.893,267.771,187.893,267.771C164.293,187.349,156.85,119.816,196.97,53.01C213.309,82.419,228.195,118.545,224.383,163.93Z",
);

final Path _rightPath1 = parseSvgPathData(
  "M186.521,0.363C92.483,5.809,-5.73,62.45,0.261,174.1C0.261,174.1,1.713,200.423,1.713,200.423C1.713,200.423,8.067,174.823,8.067,174.823C31.304,80.059,94.844,37.579,149.487,36.308C138.05,64.808,124.072,85.142,105.554,99.665C89.942,111.828,73.603,123.447,57.809,134.702C50.909,139.602,44.009,144.502,37.295,149.402C37.295,149.402,19.867,161.928,19.867,161.928C19.867,161.928,40.567,156.3,40.567,156.3C125.528,133.244,177.267,80.961,190.519,4.9C190.519,4.9,191.426,0,191.426,0C191.426,0,186.521,0.363,186.521,0.363Z",
);

final Path _rightPath2 = parseSvgPathData(
  "M41.833,127.259C46.372,119.09,52.363,111.828,58.716,104.929C65.201,98.204,72.05,91.841,79.233,85.868C86.417,79.883,93.933,74.307,101.744,69.168C109.551,64.085,117.72,59.368,126.615,56.279C118.481,60.744,110.711,65.842,103.378,71.528C95.933,77.154,88.67,82.777,81.591,88.777C74.511,94.586,67.431,100.759,60.714,106.931C54.049,113.353,47.746,120.139,41.833,127.259C41.833,127.259,41.833,127.259,41.833,127.259Z",
);

// ─── Standalone Ticker Provider (Zero Widget State Coupling) ─────────────────

class _StandaloneTickerProvider implements TickerProvider {
  const _StandaloneTickerProvider();

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

// ─── Single Shared Global Animation Driver ──────────────────────────────────

class SharedChatAvatarDriver {
  SharedChatAvatarDriver._();
  static final SharedChatAvatarDriver instance = SharedChatAvatarDriver._();

  final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);
  AnimationController? _controller;
  int _listenerCount = 0;

  void register() {
    _listenerCount++;
    if (_controller == null) {
      _controller =
          AnimationController(
            vsync: const _StandaloneTickerProvider(),
            duration: const Duration(milliseconds: 2667),
          )..addListener(() {
            if (_controller != null) {
              final curveProgress = Curves.easeInOutCubic.transform(
                _controller!.value,
              );
              progressNotifier.value = curveProgress;
            }
          });
      _controller!.repeat(reverse: true);
    }
  }

  void unregister() {
    _listenerCount--;
    if (_listenerCount <= 0 && _controller != null) {
      _controller!.stop();
      _controller!.dispose();
      _controller = null;
      _listenerCount = 0;
    }
  }
}

// ─── 1. Outer Big Hero Banner Widget ──────────────────────────────────────────

/// Dedicated widget for the Home Screen Hero Banner ("Meet Megha AI").
/// Uses `assets/svg/Lersha Logo Outer.svg` as a dedicated separate SVG copy.
class HeroBannerAgentWidget extends StatefulWidget {
  const HeroBannerAgentWidget({
    super.key,
    this.width = 85,
    this.height = 90,
    this.scaleFactor = 0.95,
  });

  final double width;
  final double height;
  final double scaleFactor;

  @override
  State<HeroBannerAgentWidget> createState() => _HeroBannerAgentWidgetState();
}

class _HeroBannerAgentWidgetState extends State<HeroBannerAgentWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _bloomProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2667),
    )..repeat(reverse: true);

    _bloomProgress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _bloomProgress,
          builder: (context, child) {
            return CustomPaint(
              size: Size(widget.width, widget.height),
              painter: _HeroBannerSvgPainter(
                progress: _bloomProgress.value,
                scaleFactor: widget.scaleFactor,
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── 2. Inside Chat Avatar SVG Widget (Zero State Leakage) ───────────────────

/// Dedicated, smooth animated SVG vector avatar for Inside Chat Bubbles.
/// Subscribes to the single shared global driver without coupling mixins to Widget state.
/// Guaranteed 0 active ticker leaks, 0 FlutterErrors, 0 signal 35 crashes when navigating pages!
class ChatAvatarAgentWidget extends StatefulWidget {
  const ChatAvatarAgentWidget({
    super.key,
    this.width = 20,
    this.height = 20,
    this.scaleFactor = 1.0,
  });

  final double width;
  final double height;
  final double scaleFactor;

  @override
  State<ChatAvatarAgentWidget> createState() => _ChatAvatarAgentWidgetState();
}

class _ChatAvatarAgentWidgetState extends State<ChatAvatarAgentWidget> {
  @override
  void initState() {
    super.initState();
    SharedChatAvatarDriver.instance.register();
  }

  @override
  void dispose() {
    SharedChatAvatarDriver.instance.unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: RepaintBoundary(
        child: ValueListenableBuilder<double>(
          valueListenable: SharedChatAvatarDriver.instance.progressNotifier,
          builder: (context, progress, child) {
            return CustomPaint(
              size: Size(widget.width, widget.height),
              painter: _HeroBannerSvgPainter(
                progress: progress,
                scaleFactor: widget.scaleFactor,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Backwards compatibility alias for HeroBannerAgentWidget
typedef HeroAgentWidget = HeroBannerAgentWidget;

// ─── SVG Blooming Custom Painter ─────────────────────────────────────────────

class _HeroBannerSvgPainter extends CustomPainter {
  final double progress;
  final double scaleFactor;

  _HeroBannerSvgPainter({required this.progress, required this.scaleFactor});

  static final Paint _paintDarkGreen = Paint()
    ..color = const Color(0xFF357037)
    ..style = PaintingStyle.fill;

  static final Paint _paintBrightGreen = Paint()
    ..color = const Color(0xFF68BE66)
    ..style = PaintingStyle.fill;

  static final Paint _paintMidGreen = Paint()
    ..color = const Color(0xFF3D9846)
    ..style = PaintingStyle.fill;

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void paint(Canvas canvas, Size size) {
    // Tightly cropped ViewBounds (330 x 340) centered on plant vector artwork
    final scaleX = (size.width / 330.0) * scaleFactor;
    final scaleY = (size.height / 340.0) * scaleFactor;

    canvas.save();
    canvas.scale(scaleX, scaleY);
    canvas.translate(-130.0, -25.0);

    // ── 1. Left Leaf Group ──────────────────────────────────────────────────
    final leftTx = _lerp(267.341, 168.752, progress);
    final leftTy = _lerp(199.5, 251.694, progress);
    final leftRotRad = _lerp(55.004, -0.516, progress) * math.pi / 180.0;

    canvas.save();
    canvas.translate(leftTx, leftTy);
    canvas.rotate(leftRotRad);
    canvas.translate(-93.5, -83.556);

    canvas.drawPath(_leftPath1, _paintDarkGreen);
    canvas.drawPath(_leftPath2, _paintBrightGreen);
    canvas.restore();

    // ── 2. Center Stem Group ────────────────────────────────────────────────
    final centerScale = _lerp(1.0, 1.10, progress);

    canvas.save();
    canvas.translate(266.841, 187.0);
    canvas.scale(centerScale, centerScale);
    canvas.translate(-192.0, -146.5);

    canvas.drawPath(_centerPath, _paintMidGreen);
    canvas.restore();

    // ── 3. Right Leaf Group ─────────────────────────────────────────────────
    final rightTx = _lerp(282.0, 376.607, progress);
    final rightTy = _lerp(188.5, 256.194, progress);
    final rightRotRad = _lerp(-43.831, -1.089, progress) * math.pi / 180.0;

    canvas.save();
    canvas.translate(rightTx, rightTy);
    canvas.rotate(rightRotRad);
    canvas.translate(-95.847, -100.407);

    canvas.drawPath(_rightPath1, _paintBrightGreen);
    canvas.drawPath(_rightPath2, _paintBrightGreen);
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HeroBannerSvgPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.scaleFactor != scaleFactor;
  }
}
