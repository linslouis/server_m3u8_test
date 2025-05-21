import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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
      home: const HlsPlayerPage(),
    );
  }
}

class HlsPlayerPage extends StatefulWidget {
  const HlsPlayerPage({super.key});

  @override
  State<HlsPlayerPage> createState() => _HlsPlayerPageState();
}

class _HlsPlayerPageState extends State<HlsPlayerPage> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    setState(() {
      _hasError = false;
    });

    // Create a VideoPlayerController pointing to the master HLS stream
    // This will use the device's Adaptive Bitrate streaming capabilities
    _controller = VideoPlayerController.network(
      'https://raw.githubusercontent.com/linslouis/server_m3u8_test/master/assets/hls-output/master.m3u8',
      formatHint: VideoFormat.hls,
    );

    // Initialize the controller and store the Future for later use
    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      // Once the video has been loaded, set to loop and autoplay
      _controller.setLooping(true);
      _controller.play();
      // Ensure the first frame is shown after initialization
      if (mounted) {
        setState(() {});
      }
      return null;
    }).catchError((error) {
      debugPrint('Error initializing video player: $error');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
      return null;
    });
  }

  @override
  void dispose() {
    // Ensure proper cleanup of the controller when the widget is removed
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HLS Video Player'),
      ),
      body: FutureBuilder(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          if (_hasError) {
            // Error state - show retry button
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Failed to load video',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Reinitialize the player on retry
                      _controller.dispose();
                      _initializePlayer();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (snapshot.connectionState == ConnectionState.done) {
            // If the initialization is complete, display the video
            return Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            );
          } else {
            // Otherwise, display a loading spinner
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Only toggle if not in error state and controller is initialized
          if (!_hasError && _controller.value.isInitialized) {
            setState(() {
              if (_controller.value.isPlaying) {
                _controller.pause();
              } else {
                _controller.play();
              }
            });
          }
        },
        child: Icon(
          (_controller.value.isInitialized && _controller.value.isPlaying)
              ? Icons.pause
              : Icons.play_arrow,
        ),
      ),
    );
  }
}
