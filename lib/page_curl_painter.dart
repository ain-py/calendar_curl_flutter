import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class PageCurlPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final Offset pointer;
  final Offset origin;
  final double radius;
  final bool drawBackground;
  final ui.Image frontImage;
  final ui.Image backImage;

  PageCurlPainter({
    required this.shader,
    required this.pointer,
    required this.origin,
    required this.radius,
    this.drawBackground = true,
    required this.frontImage,
    required this.backImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. u_resolution (vec2 takes indices 0 and 1)
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);

    // 2. u_pointer (vec2 takes indices 2 and 3)
    shader.setFloat(2, pointer.dx);
    shader.setFloat(3, pointer.dy);

    // 3. u_origin (vec2 takes indices 4 and 5)
    shader.setFloat(4, origin.dx);
    shader.setFloat(5, origin.dy);

    // 4. u_radius (float takes index 6)
    shader.setFloat(6, radius);

    // 5. u_draw_background (float takes index 7)
    shader.setFloat(7, drawBackground ? 1.0 : 0.0);

    // Set the texture samplers
    shader.setImageSampler(0, frontImage);
    shader.setImageSampler(1, backImage);

    // Draw a rectangle covering the whole canvas using the shader
    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant PageCurlPainter oldDelegate) {
    return oldDelegate.pointer != pointer || oldDelegate.radius != radius;
  }
}
