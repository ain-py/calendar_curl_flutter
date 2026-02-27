// calendar_flip_shader.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CalendarFlipShader extends StatefulWidget {
  final int startDay;
  final int endDay;
  final Duration flipDuration;
  final VoidCallback? onComplete;

  const CalendarFlipShader({
    super.key,
    this.startDay = 1,
    this.endDay = 31,
    this.flipDuration = const Duration(milliseconds: 600),
    this.onComplete,
  });

  @override
  State<CalendarFlipShader> createState() => _CalendarFlipShaderState();
}

class _CalendarFlipShaderState extends State<CalendarFlipShader>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  int _currentIndex = 0;
  ui.FragmentShader? _shader;
  bool _shaderLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _initAnimations();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/calander_v3.frag',
      );
      _shader = program.fragmentShader();
      setState(() => _shaderLoaded = true);
    } catch (e) {
      debugPrint('Shader load error: $e');
    }
  }

  void _initAnimations() {
    final count = widget.endDay - widget.startDay + 1;
    _controllers = List.generate(
      count,
      (index) =>
          AnimationController(vsync: this, duration: widget.flipDuration),
    );

    _animations = _controllers.map((ctrl) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: ctrl,
          curve: const Interval(0.0, 1.0, curve: Curves.easeInOutCubic),
        ),
      );
    }).toList();

    // Chain animations
    for (int i = 0; i < count - 1; i++) {
      _controllers[i].addStatusListener((status) {
        if (status == AnimationStatus.completed && i + 1 < count) {
          setState(() => _currentIndex = i + 1);
          _controllers[i + 1].forward();
        }
      });
    }

    // Start first animation
    if (count > 0) {
      _controllers[0].forward();
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shaderLoaded || _shader == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomPaint(
      size: Size.infinite,
      painter: _CalendarFlipPainter(
        shader: _shader!,
        animations: _animations,
        currentIndex: _currentIndex,
        startDay: widget.startDay,
      ),
    );
  }
}

class _CalendarFlipPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final List<Animation<double>> animations;
  final int currentIndex;
  final int startDay;

  _CalendarFlipPainter({
    required this.shader,
    required this.animations,
    required this.currentIndex,
    required this.startDay,
  }) : super(repaint: Listenable.merge(animations));

  @override
  void paint(Canvas canvas, Size size) {
    // Draw static pages (already flipped)
    for (int i = 0; i < currentIndex; i++) {
      _drawPage(canvas, size, i, 1.0); // Completed
    }

    // Draw current animating page
    if (currentIndex < animations.length) {
      final progress = animations[currentIndex].value;
      _drawPage(canvas, size, currentIndex, progress);
    }

    // Draw next page underneath (peek-through effect)
    if (currentIndex + 1 < animations.length) {
      _drawNextPageHint(canvas, size, currentIndex + 1);
    }
  }

  // In your painter's paint method:
  void _drawPage(Canvas canvas, Size size, int index, double progress) {
    // Set uniforms by index, not by name
    shader.setFloat(0, DateTime.now().millisecondsSinceEpoch / 1000.0); // uTime
    shader.setFloat(1, size.width); // uResolution.x
    shader.setFloat(2, size.height); // uResolution.y
    shader.setFloat(3, progress); // uProgress
    shader.setFloat(4, (startDay + index).toDouble()); // uPageIndex

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _drawNextPageHint(Canvas canvas, Size size, int nextIndex) {
    // Subtle shadow/hint of next page
    final rect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.52),
      width: size.width * 0.85,
      height: size.height * 0.85,
    );

    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.black.withOpacity(0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  @override
  bool shouldRepaint(covariant _CalendarFlipPainter oldDelegate) => true;
}

// Alternative: Simplified version using Flutter's built-in shaders
class CalendarFlipWidget extends StatelessWidget {
  final int day;
  final double progress;

  const CalendarFlipWidget({
    super.key,
    required this.day,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(200, 240),
      painter: _SimpleCalendarPainter(day: day, progress: progress),
    );
  }
}

class _SimpleCalendarPainter extends CustomPainter {
  final int day;
  final double progress;

  _SimpleCalendarPainter({required this.day, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Calculate flip transform
    final lift = Curves.easeInOut.transform(
      progress < 0.2 ? progress * 5 : 1.0,
    );
    final fly = Curves.easeInOut.transform(
      progress > 0.3 ? (progress - 0.3) / 0.7 : 0.0,
    );

    // Shadow
    final shadowPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center + Offset(-10 - fly * 30, 10 + fly * 20),
            width: size.width * 0.9 * (1 - fly * 0.2),
            height: size.height * 0.9 * (1 - fly * 0.2),
          ),
          const Radius.circular(12),
        ),
      );

    canvas.drawShadow(
      shadowPath,
      Colors.black.withOpacity(0.3 * (1 - progress)),
      20,
      true,
    );

    // Save layer for clipping
    canvas.save();

    // Apply 3D transform simulation
    final skewMatrix = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..rotateX(-fly * 0.8)
      ..rotateY(-fly * 1.2)
      ..translate(-center.dx, -center.dy);

    // Header
    final headerPaint = Paint()..color = const Color(0xFFFF4757);
    final headerRect = Rect.fromLTWH(
      size.width * 0.05,
      size.height * 0.05 + lift * -10,
      size.width * 0.9,
      size.height * 0.25,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(headerRect, const Radius.circular(12)),
      headerPaint,
    );

    // Body
    final bodyPaint = Paint()..color = Colors.white;
    final bodyRect = Rect.fromLTWH(
      size.width * 0.05,
      headerRect.bottom - 5,
      size.width * 0.9,
      size.height * 0.65,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(12)),
      bodyPaint,
    );

    // Perforation dots
    final dotPaint = Paint()..color = const Color(0xFF1A1A1A);
    const dotSpacing = 25.0;
    const dotRadius = 4.0;

    for (
      double x = bodyRect.left + 10;
      x < bodyRect.right - 10;
      x += dotSpacing
    ) {
      canvas.drawCircle(
        Offset(x, headerRect.bottom - 2.5),
        dotRadius,
        dotPaint,
      );
    }

    // Number
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$day',
        style: TextStyle(
          fontSize: 72 * (1 - fly * 0.3),
          fontWeight: FontWeight.bold,
          color: const Color(0xFF2D3436),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2 - 10),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SimpleCalendarPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.day != day;
}
