import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'page_curl_painter.dart';

class InteractiveCalendar extends StatefulWidget {
  final ui.Image frontPageImage; // E.g., The "1" calendar page
  final ui.Image backPageImage; // E.g., The blank calendar page beneath it

  const InteractiveCalendar({
    Key? key,
    required this.frontPageImage,
    required this.backPageImage,
  }) : super(key: key);

  @override
  State<InteractiveCalendar> createState() => InteractiveCalendarState();
}

class InteractiveCalendarState extends State<InteractiveCalendar>
    with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _program;
  Offset _pointer = const Offset(300, 300);
  final Offset _origin = const Offset(
    300,
    300,
  ); // Peeling from the bottom-right

  late AnimationController _animationController;
  late Animation<Offset> _flyAnimation;
  late Animation<double> _moveAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _loadShader();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // The curl starts instantly.
    // Animate pointer from bottom-right (300, 300) to top-left way outside
    _flyAnimation =
        Tween<Offset>(
          begin: const Offset(300, 300),
          end: const Offset(
            -1000,
            -300,
          ), // More horizontal drift, less extreme vertical
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInQuad, // Accelerate like wind picking it up
          ),
        );

    // The physical page lifting off the screen waits until the curl is 30% done
    _moveAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeInQuad),
    );

    // The opacity only starts fading out in the last half of the animation
    _opacityAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.5, 1.0, curve: Curves.linear),
    );

    _animationController.addListener(() {
      setState(() {
        _pointer = _flyAnimation.value;
      });
    });
  }

  void togglePlay() {
    if (_animationController.isAnimating) {
      _animationController.stop();
    } else {
      if (_animationController.isCompleted) {
        _animationController.reset();
        setState(() {
          _pointer = const Offset(300, 300);
        });
      }
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadShader() async {
    // Load the shader from your asset bundle
    final program = await ui.FragmentProgram.fromAsset(
      'shaders/calander_v4.frag',
    );
    setState(() {
      _program = program;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_program == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      // When the user drags, update the pointer position
      onPanUpdate: (details) {
        setState(() {
          _pointer = details.localPosition;
        });
      },
      // When the user lets go, snap the page back to the bottom-right
      onPanEnd: (details) {
        setState(() {
          _pointer = const Offset(300, 300);
        });
        // Note: For a production app, you'd use an AnimationController
        // here to smoothly animate the _pointer back to const Offset(300, 300).
      },
      child: SizedBox(
        width: 300,
        height: 300,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Base page (unmoving)
            Positioned(
              left: 0,
              top: 0,
              child: CustomPaint(
                size: const Size(300, 300),
                painter: PageCurlPainter(
                  shader: _program!.fragmentShader(),
                  pointer: const Offset(300, 300), // No curl on the base
                  origin: _origin,
                  radius: 40.0,
                  frontImage: widget.backPageImage, // Show back page as base
                  backImage: widget.backPageImage,
                ),
              ),
            ),
            // Peeling page (animates position and curl)
            Positioned(
              left:
                  _animationController.isAnimating ||
                      _animationController.isCompleted
                  ? -(_moveAnimation.value * 550) // Move left out of screen
                  : 0,
              top:
                  _animationController.isAnimating ||
                      _animationController.isCompleted
                  ? -(_moveAnimation.value *
                        _moveAnimation.value *
                        10) // Quadratic upward for wind lift
                  : 0,
              child: CustomPaint(
                size: const Size(300, 300),
                painter: PageCurlPainter(
                  shader: _program!.fragmentShader(),
                  pointer: _pointer,
                  origin: _origin,
                  radius: 70.0,
                  drawBackground: false,
                  frontImage: widget.frontPageImage,
                  backImage: widget.backPageImage,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
