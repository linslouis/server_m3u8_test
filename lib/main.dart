import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

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
  // Initialize with a dummy value to prevent late initialization errors
  late VideoPlayerController _controller = VideoPlayerController.networkUrl(
    Uri.parse('https://example.com/dummy.m3u8'),
    formatHint: VideoFormat.hls,
  );
  // Initialize with a future that completes immediately
  late Future<void> _initializeVideoPlayerFuture = Future.value();
  bool _hasError = false;
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  
  // Example video playlists - replace with your actual API response
  final Map<String, String> _playlists = {
    'avc': 'https://raw.githubusercontent.com/linslouis/server_m3u8_test/master/assets/hls-output/master.m3u8',
    'hevc': 'https://raw.githubusercontent.com/linslouis/server_m3u8_test/master/assets/hls-output-hevc/master.m3u8',
  };

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<bool> _isHevcSupported() async {
    if (Platform.isIOS) {
      final iosInfo = await _deviceInfoPlugin.iosInfo;
      // iOS 11.0 and above supports HEVC
      final version = iosInfo.systemVersion.split('.');
      if (version.isNotEmpty && int.tryParse(version[0]) != null) {
        return int.parse(version[0]) >= 11;
      }
      return false;
    } else if (Platform.isAndroid) {
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      // Android API 29 (Android 10) and above supports HEVC
      return androidInfo.version.sdkInt >= 29;
    }
    return false;
  }

  Future<bool> _isEmulator() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      return androidInfo.isPhysicalDevice == false || 
             androidInfo.model.toLowerCase().contains('emulator') ||
             androidInfo.model.toLowerCase().contains('sdk');
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfoPlugin.iosInfo;
      return iosInfo.isPhysicalDevice == false ||
             iosInfo.name.toLowerCase().contains('simulator');
    }
    return false;
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _hasError = false;
    });

    // First check if HEVC is supported
    final bool hevcSupported = await _isHevcSupported();
    
    // On emulators, forcibly use AVC regardless of API level
    final bool isEmulator = await _isEmulator();
    final bool shouldTryHevc = hevcSupported && !isEmulator;
    
    debugPrint('Device supports HEVC: $hevcSupported, Is emulator: $isEmulator');
    
    // Choose URL based on device capability
    String videoUrl = shouldTryHevc ? _playlists['hevc']! : _playlists['avc']!;
    
    debugPrint('Initial video URL: $videoUrl');
    
    // Initialize with the selected URL
    await _initializeWithUrl(videoUrl);
    
    // If HEVC failed and we tried it first, fall back to AVC
    if (_hasError && shouldTryHevc) {
      debugPrint('HEVC playback failed, falling back to AVC');
      await _initializeWithUrl(_playlists['avc']!);
    }
  }

  Future<void> _initializeWithUrl(String url) async {
    // Create a local variable for tracking controller existence
    VideoPlayerController? oldController;
    
    // Store the old controller if it's already been initialized
    try {
      oldController = _controller;
    } catch (e) {
      // _controller might not be initialized yet on first call
    }
    
    // Dispose old controller if it exists
    if (oldController != null) {
      await oldController.dispose();
    }

    // Create a VideoPlayerController pointing to the selected HLS stream
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      formatHint: VideoFormat.hls,
    );

    // Initialize the controller and store the Future
    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      // Once the video has been loaded, set to loop and autoplay
      _controller.setLooping(true);
      _controller.play();
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
