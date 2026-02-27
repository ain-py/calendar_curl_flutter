import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'interactive_calendar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar Shader App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF4757)),
        useMaterial3: true,
      ),
      home: const CalendarDemoPage(),
    );
  }
}

class CalendarDemoPage extends StatefulWidget {
  const CalendarDemoPage({super.key});

  @override
  State<CalendarDemoPage> createState() => _CalendarDemoPageState();
}

class _CalendarDemoPageState extends State<CalendarDemoPage> {
  ui.Image? _frontImage;
  ui.Image? _backImage;
  final GlobalKey<InteractiveCalendarState> _calendarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final front = await _generatePageImage(15);
    final back = await _generatePageImage(16);
    if (mounted) {
      setState(() {
        _frontImage = front;
        _backImage = back;
      });
    }
  }

  Future<ui.Image> _generatePageImage(int day) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(300, 300);

    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.elliptical(5, 5),
      ),
      bgPaint,
    );

    // // Header
    // final headerPaint = Paint()..color = const Color(0xFFFF4757);
    // final headerRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.25);
    // canvas.drawRRect(
    //   RRect.fromRectAndCorners(
    //     headerRect,
    //     topLeft: const Radius.circular(12),
    //     topRight: const Radius.circular(12),
    //   ),
    //   headerPaint,
    // );

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
        (size.height * 0.75 - textPainter.height) / 2,
      ),
    );

    return recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA), // Light grey background
      appBar: AppBar(
        title: const Text('Calendar Page-Curl Shader'),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 50,
              width: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                color: Color(0xFFFF4757),
              ),
            ),
            // Calendar Widget
            if (_frontImage != null && _backImage != null)
              InteractiveCalendar(
                key: _calendarKey,
                frontPageImage: _frontImage!,
                backPageImage: _backImage!,
              )
            else
              const SizedBox(
                width: 300,
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              ),

            const SizedBox(height: 60),

            // // Demo Controls
            // Container(
            //   width: 320,
            //   padding: const EdgeInsets.all(20),
            //   decoration: BoxDecoration(
            //     color: Colors.white,
            //     borderRadius: BorderRadius.circular(16),
            //     boxShadow: [
            //       BoxShadow(
            //         color: Colors.black.withValues(alpha: 0.05),
            //         blurRadius: 10,
            //         offset: const Offset(0, 4),
            //       ),
            //     ],
            //   ),
            //   child: Column(
            //     children: [
            //       const Text(
            //         'Animation Controls',
            //         style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            //       ),
            //       const SizedBox(height: 16),
            //       const Text(
            //         'Drag from the bottom-right corner to peel the page!',
            //         style: TextStyle(color: Colors.grey, fontSize: 12),
            //         textAlign: TextAlign.center,
            //       ),
            //       const SizedBox(height: 16),
            //       FilledButton.icon(
            //         onPressed: () {
            //           _calendarKey.currentState?.togglePlay();
            //         },
            //         icon: const Icon(Icons.play_arrow),
            //         label: const Text('Play / Pause Wind'),
            //         style: FilledButton.styleFrom(
            //           backgroundColor: const Color(0xFFFF4757),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
