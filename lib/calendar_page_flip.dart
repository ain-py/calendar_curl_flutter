import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class AnimatedCalendar extends StatefulWidget {
  final int initialDate;
  final VoidCallback? onPageFlipped;
  final double flipSpeed;
  final bool enableShadows;

  const AnimatedCalendar({
    super.key,
    this.initialDate = 15,
    this.onPageFlipped,
    this.flipSpeed = 1.0,
    this.enableShadows = true,
  });

  @override
  State<AnimatedCalendar> createState() => _AnimatedCalendarState();
}

class _AnimatedCalendarState extends State<AnimatedCalendar>
    with SingleTickerProviderStateMixin {
  late ui.FragmentProgram _program;
  bool _shaderLoaded = false;
  late AnimationController _controller;

  // Animation phases
  late Animation<double> _liftAnimation;
  late Animation<double> _tearAnimation;
  late Animation<double> _flightAnimation;

  ui.Image? _currentPageImage;
  ui.Image? _nextPageImage;
  int _currentDate = 15;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.initialDate;
    _loadShader();
    _initAnimations();
  }

  @override
  void didUpdateWidget(covariant AnimatedCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flipSpeed != widget.flipSpeed) {
      _controller.duration = Duration(
        milliseconds: (750 / widget.flipSpeed).round(),
      );
    }
  }

  void _initAnimations() {
    // idle -> lift (150ms) -> tear (100ms) -> flight & exit (500ms)
    // total: 750ms
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (750 / widget.flipSpeed).round()),
    );

    // Lift is 0.0 to 0.2 (150/750)
    _liftAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.2, curve: Curves.easeOutCubic),
      ),
    );

    // Tear is 0.2 to 0.33 (100/750)
    _tearAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.33, curve: Curves.linear),
      ),
    );

    // Flight & Exit is 0.33 to 1.0 (500/750)
    _flightAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.33, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentDate = _currentDate < 31 ? _currentDate + 1 : 1;
          _currentPageImage = _nextPageImage;
        });
        _generatePageImage(
          _currentDate < 31 ? _currentDate + 1 : 1,
        ).then((img) => _nextPageImage = img);
        _controller.reset();
        widget.onPageFlipped?.call();
      }
    });
  }

  Future<void> _loadShader() async {
    try {
      _program = await ui.FragmentProgram.fromAsset(
        'shaders/calendar_flip.frag',
      );

      _currentPageImage = await _generatePageImage(_currentDate);
      _nextPageImage = await _generatePageImage(
        _currentDate < 31 ? _currentDate + 1 : 1,
      );

      if (mounted) {
        setState(() {
          _shaderLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to load shader: $e');
    }
  }

  Future<ui.Image> _generatePageImage(int day) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(300, 300);

    // Shadows around the page
    if (widget.enableShadows) {
      // A subtle shadow effect will be built into the widget rather than image
      // to allow dynamic shadow during flight. But base page can have some ambient shadow.
    }

    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      bgPaint,
    );

    // Header
    final headerPaint = Paint()..color = const Color(0xFFFF4757);
    final headerRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.25);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        headerRect,
        topLeft: const Radius.circular(12),
        topRight: const Radius.circular(12),
      ),
      headerPaint,
    );

    // Text
    final textPainter = TextPainter(
      text: TextSpan(
        text: day.toString(),
        style: const TextStyle(
          color: Color(0xFF2D3436),
          fontSize: 80,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        headerRect.bottom + (size.height * 0.75 - textPainter.height) / 2,
      ),
    );

    return recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
  }

  void _flip() {
    if (!_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shaderLoaded || _currentPageImage == null || _nextPageImage == null) {
      return const SizedBox(
        width: 300,
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: const Size(300, 300),
            painter: CalendarPainter(
              shader: _program.fragmentShader(),
              currentImage: _currentPageImage!,
              nextImage: _nextPageImage!,
              progress: _controller.value,
              liftProgress: _liftAnimation.value,
              tearProgress: _tearAnimation.value,
              flightProgress: _flightAnimation.value,
              enableShadows: widget.enableShadows,
            ),
          );
        },
      ),
    );
  }
}

class CalendarPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image currentImage;
  final ui.Image nextImage;
  final double progress;
  final double liftProgress;
  final double tearProgress;
  final double flightProgress;
  final bool enableShadows;

  CalendarPainter({
    required this.shader,
    required this.currentImage,
    required this.nextImage,
    required this.progress,
    required this.liftProgress,
    required this.tearProgress,
    required this.flightProgress,
    required this.enableShadows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Draw base shadow for the whole stack
    if (enableShadows) {
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.translate(4, 8),
          const Radius.circular(12),
        ),
        shadowPaint,
      );
    }

    // Draw the next page underneath statically
    final nextPaint = Paint()..color = Colors.white;
    canvas.drawImageRect(
      nextImage,
      Rect.fromLTWH(
        0,
        0,
        nextImage.width.toDouble(),
        nextImage.height.toDouble(),
      ),
      rect,
      nextPaint,
    );

    // Draw shading over the next page to give stack depth / shadow from flying page
    if (enableShadows && flightProgress > 0) {
      final dropShadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.2 * (1.0 - flightProgress))
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          10.0 + (flightProgress * 20.0),
        );
      canvas.drawRect(rect, dropShadowPaint);
    }

    // Prepare uniforms
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);

    shader.setFloat(2, progress);
    shader.setFloat(3, liftProgress);
    shader.setFloat(4, tearProgress);
    shader.setFloat(5, flightProgress);
    shader.setImageSampler(0, currentImage);

    final shaderPaint = Paint()..shader = shader;

    canvas.save();
    if (flightProgress > 0) {
      // Rotate and move for flight phase
      double moveX = -size.width * 1.5 * flightProgress;
      double moveY = -size.height * 0.8 * flightProgress;
      double rot = -0.6 * flightProgress; // rotation (radians)
      double scale = 1.0 - (0.4 * flightProgress);

      canvas.translate(size.width / 2 + moveX, size.height / 2 + moveY);
      canvas.rotate(rot);
      canvas.scale(scale);
      canvas.translate(-size.width / 2, -size.height / 2);
    }

    canvas.drawRect(rect, shaderPaint);
    canvas.restore();

    // Draw the static header of the CURRENT page if it's tearing/flying
    if (tearProgress > 0 || flightProgress > 0) {
      final headerHeight = size.height * 0.25;
      canvas.drawImageRect(
        currentImage,
        Rect.fromLTWH(
          0,
          0,
          currentImage.width.toDouble(),
          currentImage.height.toDouble() * 0.25,
        ),
        Rect.fromLTWH(0, 0, size.width, headerHeight),
        Paint(),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CalendarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.liftProgress != liftProgress ||
        oldDelegate.tearProgress != tearProgress ||
        oldDelegate.flightProgress != flightProgress ||
        oldDelegate.currentImage != currentImage ||
        oldDelegate.nextImage != nextImage ||
        oldDelegate.enableShadows != enableShadows;
  }
}
