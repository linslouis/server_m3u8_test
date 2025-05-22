import 'package:flutter/material.dart';
import 'controllers/video_player_controller.dart';
import 'screens/video_player_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HLS Player Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HlsPlayerScreen(
        controller: HlsPlayerController(),
      ),
    );
  }
}
