import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart' as video;
import '../controllers/video_player_controller.dart';

class HlsPlayerScreen extends StatefulWidget {
  final HlsPlayerController controller;

  const HlsPlayerScreen({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<HlsPlayerScreen> createState() => _HlsPlayerScreenState();
}

class _HlsPlayerScreenState extends State<HlsPlayerScreen> {
  late video.VideoPlayerController _videoController;
  late Future<void> _initializeVideoPlayerFuture = Future.value();
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _hasError = false;
    });

    try {
      // Initialize with a dummy controller to prevent late initialization errors
      _videoController = video.VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/dummy.m3u8'),
        formatHint: video.VideoFormat.hls,
      );

      // Get the appropriate controller based on device capabilities
      _videoController = await widget.controller.createVideoPlayerController();

      // Initialize and configure the controller
      _initializeVideoPlayerFuture = _videoController.initialize().then((_) {
        // Once the video has been loaded, set to loop and autoplay
        _videoController.setLooping(true);
        _videoController.play();
        
        // Ensure the first frame is shown after initialization
        if (mounted) {
          setState(() {
            _hasError = false;
          });
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
    } catch (e) {
      debugPrint('Exception during player initialization: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    // Ensure proper cleanup of the controller when the widget is removed
    _videoController.dispose();
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
                aspectRatio: _videoController.value.aspectRatio,
                child: video.VideoPlayer(_videoController),
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
          if (!_hasError && _videoController.value.isInitialized) {
            setState(() {
              if (_videoController.value.isPlaying) {
                _videoController.pause();
              } else {
                _videoController.play();
              }
            });
          }
        },
        child: Icon(
          (_videoController.value.isInitialized && _videoController.value.isPlaying)
              ? Icons.pause
              : Icons.play_arrow,
        ),
      ),
    );
  }
} 