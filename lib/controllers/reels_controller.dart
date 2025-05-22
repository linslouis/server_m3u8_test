import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../models/video_item.dart';
import '../services/video_feed_service.dart';

class ReelsController {
  final VideoFeedService _videoFeedService = VideoFeedService();
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  
  // Store videos fetched from API
  List<VideoItem> _videos = [];
  
  // Currently visible video index
  int _currentIndex = 0;
  
  // Maps to store video controllers for preloaded videos
  final Map<int, VideoPlayerController> _videoControllers = {};
  final Map<int, VideoPlayerController> _previewControllers = {};
  
  // Map to store initialization futures
  final Map<int, Future<void>> _initializationFutures = {};
  final Map<int, Future<void>> _previewInitializationFutures = {};
  
  // Track which videos are using preview vs full version
  final Set<int> _showingPreview = {};
  
  // Maximum number of active decoder instances to maintain
  static const int _maxDecoderInstances = 3; // Reduced from 5 to prevent memory issues
  
  // Stream to notify UI of state changes
  final _stateController = StreamController<ReelsState>.broadcast();
  Stream<ReelsState> get stateStream => _stateController.stream;
  
  ReelsState _currentState = ReelsState.loading;
  ReelsState get currentState => _currentState;
  
  // Gesture velocity tracking for buffer management
  double _currentVelocity = 0;
  
  // Buffer size multiplier based on gesture velocity
  // Default to 1.0, increases for slow drags, decreases for fast flings
  double _bufferSizeMultiplier = 1.0;
  
  // Get the current visible video
  VideoItem? get currentVideo => 
      _videos.isNotEmpty && _currentIndex >= 0 && _currentIndex < _videos.length 
          ? _videos[_currentIndex] 
          : null;
  
  // Get all videos
  List<VideoItem> get videos => _videos;
  
  // Get current index
  int get currentIndex => _currentIndex;
  
  /// Initialize the controller
  Future<void> initialize() async {
    _updateState(ReelsState.loading);
    
    try {
      // Fetch videos from API
      _videos = await _videoFeedService.fetchVideoFeed();
      
      if (_videos.isEmpty) {
        _updateState(ReelsState.error);
        return;
      }
      
      // Preload initial set of videos
      await _preloadVideosAroundIndex(0);
      
      _updateState(ReelsState.ready);
    } catch (e) {
      debugPrint('Error initializing reels controller: $e');
      _updateState(ReelsState.error);
    }
  }
  
  /// Preload videos around the current index (±2 videos)
  Future<void> _preloadVideosAroundIndex(int index) async {
    // Calculate the range of indices to preload
    final startIndex = (index - 2).clamp(0, _videos.length - 1);
    final endIndex = (index + 2).clamp(0, _videos.length - 1);
    
    // Create a list of indices to preload
    final indicesToPreload = List.generate(
      endIndex - startIndex + 1, 
      (i) => startIndex + i
    );
    
    // First, ensure we're not exceeding maximum decoder instances
    _enforceDecoderLimit();
    
    // Preload each video in the range
    for (final i in indicesToPreload) {
      try {
        await _preloadVideo(i);
      } catch (e) {
        debugPrint('Error preloading video at index $i: $e');
        // Continue with other videos even if one fails
      }
    }
    
    // Dispose controllers for videos outside the preload range
    _videoControllers.keys.toList().forEach((i) {
      if (i < startIndex || i > endIndex) {
        _disposeController(i);
      }
    });
    
    _previewControllers.keys.toList().forEach((i) {
      if (i < startIndex || i > endIndex) {
        _disposePreviewController(i);
      }
    });
    
    // Ensure we don't exceed maximum decoder instances after preloading
    _enforceDecoderLimit();
  }
  
  /// Enforce limit on active decoder instances
  void _enforceDecoderLimit() {
    // Count active decoders (both main and preview)
    final totalDecoders = _videoControllers.length + _previewControllers.length;
    
    if (totalDecoders <= _maxDecoderInstances) return;
    
    // Calculate how many to remove
    final toRemove = totalDecoders - _maxDecoderInstances;
    
    // Create list of candidates for removal, prioritizing by distance from current index
    final candidates = <int>[];
    
    // Add indices from both controller maps, excluding current index
    candidates.addAll(_videoControllers.keys.where((i) => i != _currentIndex));
    candidates.addAll(_previewControllers.keys.where((i) => i != _currentIndex));
    
    // Sort by distance from current index (furthest first)
    candidates.sort((a, b) {
      final distA = (a - _currentIndex).abs();
      final distB = (b - _currentIndex).abs();
      return distB.compareTo(distA); // Descending order
    });
    
    // Remove the furthest controllers
    for (int i = 0; i < toRemove && i < candidates.length; i++) {
      final index = candidates[i];
      
      if (_videoControllers.containsKey(index)) {
        _disposeController(index);
      } else if (_previewControllers.containsKey(index)) {
        _disposePreviewController(index);
      }
    }
  }
  
  /// Preload a specific video
  Future<void> _preloadVideo(int index) async {
    if (index < 0 || index >= _videos.length) return;
    
    // Skip if already fully preloaded
    if (_videoControllers.containsKey(index) && 
        _videoControllers[index]!.value.isInitialized &&
        !_showingPreview.contains(index)) {
      return;
    }
    
    final videoItem = _videos[index];
    
    try {
      // Step 1: Load the preview clip first (5 seconds)
      await _preloadPreviewClip(index, videoItem);
      
      // Step 2: In parallel, load the full video stream
      _preloadFullVideo(index, videoItem);
      
    } catch (e) {
      debugPrint('Exception during preloading video $index: $e');
    }
  }
  
  /// Preload a 5-second preview clip
  Future<void> _preloadPreviewClip(int index, VideoItem videoItem) async {
    // Skip if preview already loaded
    if (_previewControllers.containsKey(index) && 
        _previewControllers[index]!.value.isInitialized) {
      return;
    }
    
    try {
      // Determine best video format based on device capabilities
      final String videoUrl = await _getBestVideoUrl(videoItem);
      
      // Create and initialize the preview controller
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        formatHint: VideoFormat.hls,
        httpHeaders: {
          // Set custom headers to request only a 5-second segment
          // This is a simplified example - real implementation would depend on CDN/server capabilities
          'Range': 'bytes=0-', // Request from the start
          'X-Preview-Duration': '5', // Custom header indicating we want a preview
        },
      );
      
      _previewControllers[index] = controller;
      
      // Initialize the controller
      _previewInitializationFutures[index] = controller.initialize().then((_) {
        // Extract first frame if not already done
        if (!videoItem.hasFirstFrame) {
          _extractFirstFrame(index, controller, videoItem);
        }
        
        // Set to loop the preview
        controller.setLooping(true);
        
        // If this is the current video, start playing the preview
        if (index == _currentIndex) {
          controller.play();
          _showingPreview.add(index);
        }
        
        return null;
      }).catchError((error) {
        debugPrint('Error initializing preview for video $index: $error');
        return null;
      });
      
      await _previewInitializationFutures[index];
    } catch (e) {
      debugPrint('Exception during preloading preview for video $index: $e');
    }
  }
  
  /// Extract the first frame from a video controller
  Future<void> _extractFirstFrame(int index, VideoPlayerController controller, VideoItem videoItem) async {
    try {
      // First, check if we need to extract the frame
      if (videoItem.hasFirstFrame) return;
      
      // Ensure controller is initialized
      if (!controller.value.isInitialized) {
        await controller.initialize();
      }
      
      // Seek to beginning of video
      bool wasPlaying = controller.value.isPlaying;
      if (wasPlaying) {
        await controller.pause();
      }
      
      // Seek to first frame
      await controller.seekTo(Duration.zero);
      
      // This is a bit of a hack - we need to trigger a frame to be rendered
      // We'll play for a short duration then pause
      await controller.play();
      await Future.delayed(const Duration(milliseconds: 100));
      await controller.pause();
      
      // Create a memory image from the frame (dummy implementation)
      // In a real app, you'd use platform channels or another approach to capture the frame
      // This is just a placeholder - the actual frame capture requires more complex native code
      
      // For now, we'll just mark that we've processed the first frame
      // and the ReelVideoPlayer will handle showing the paused video as the "thumbnail"
      videoItem.hasFirstFrame = true;
      
      // Resume playback if needed
      if (wasPlaying && index == _currentIndex) {
        await controller.play();
      }
    } catch (e) {
      debugPrint('Error extracting first frame for video $index: $e');
    }
  }
  
  /// Preload full video in parallel
  Future<void> _preloadFullVideo(int index, VideoItem videoItem) async {
    // Skip if full video already loaded
    if (_videoControllers.containsKey(index) && 
        _videoControllers[index]!.value.isInitialized) {
      return;
    }
    
    try {
      // Determine best video format based on device capabilities
      final String videoUrl = await _getBestVideoUrl(videoItem);
      
      // Create controller with adaptive streaming configuration
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        formatHint: VideoFormat.hls,
        // Adjust buffer size based on gesture velocity
        // Smaller buffer for fast swipes, larger for slow browsing
        videoPlayerOptions: VideoPlayerOptions(
          // Apply buffer size multiplier based on gesture velocity
          allowBackgroundPlayback: false,
          mixWithOthers: false,
        ),
      );
      
      _videoControllers[index] = controller;
      
      // Initialize the controller
      _initializationFutures[index] = controller.initialize().then((_) {
        // Extract first frame if not already done
        if (!videoItem.hasFirstFrame) {
          _extractFirstFrame(index, controller, videoItem);
        }
        
        // Set to loop
        controller.setLooping(true);
        
        // If this is the current video and we're showing a preview,
        // we'll need to swap from preview to full video later
        if (index == _currentIndex && _showingPreview.contains(index)) {
          _schedulePreviewToFullSwap(index);
        }
        
        return null;
      }).catchError((error) {
        debugPrint('Error initializing full video $index: $error');
        return null;
      });
    } catch (e) {
      debugPrint('Exception during preloading full video $index: $e');
    }
  }
  
  /// Schedule the swap from preview to full video at a segment boundary
  void _schedulePreviewToFullSwap(int index) {
    if (!_previewControllers.containsKey(index) || 
        !_videoControllers.containsKey(index)) {
      return;
    }
    
    final previewController = _previewControllers[index]!;
    final fullController = _videoControllers[index]!;
    
    // Add listener to detect when we reach end of a segment
    // This is a simplified approach - in a real app, you'd analyze the HLS manifest
    // to detect segment boundaries precisely
    void positionListener() {
      if (!_showingPreview.contains(index)) {
        // Already swapped, remove listener
        previewController.removeListener(positionListener);
        return;
      }
      
      // Check if we're at a segment boundary
      // For this example, we'll swap after 5 seconds or at the end of the preview
      final position = previewController.value.position;
      if (position.inSeconds >= 5 || 
          position >= previewController.value.duration - const Duration(milliseconds: 100)) {
        // Swap to full video
        _swapToFullVideo(index);
        
        // Remove listener
        previewController.removeListener(positionListener);
      }
    }
    
    // Add the listener
    previewController.addListener(positionListener);
  }
  
  /// Swap from preview to full video
  Future<void> _swapToFullVideo(int index) async {
    if (!_previewControllers.containsKey(index) || 
        !_videoControllers.containsKey(index) ||
        !_showingPreview.contains(index)) {
      return;
    }
    
    final previewController = _previewControllers[index]!;
    final fullController = _videoControllers[index]!;
    
    try {
      // Get current position from preview
      final position = previewController.value.position;
      
      // Pause preview
      await previewController.pause();
      
      // Seek full video to current position
      await fullController.seekTo(position);
      
      // Start playing full video
      await fullController.play();
      
      // Remove from showing preview set
      _showingPreview.remove(index);
      
      // Notify UI to rebuild
      _stateController.add(ReelsState.videoSwapped);
    } catch (e) {
      debugPrint('Error swapping to full video for index $index: $e');
    }
  }
  
  /// Change to a specific video index
  Future<void> changeToIndex(int index) async {
    if (index < 0 || index >= _videos.length || index == _currentIndex) return;
    
    // Pause current video (either preview or full)
    await pauseCurrentVideo();
    
    final previousIndex = _currentIndex;
    _currentIndex = index;
    
    // Preload videos around new index
    await _preloadVideosAroundIndex(index);
    
    // Play the new current video (either preview or full)
    await playCurrentVideo();
    
    // Notify listeners of index change
    _stateController.add(ReelsState.indexChanged);
  }
  
  /// Pause the current video
  Future<void> pauseCurrentVideo() async {
    if (_currentIndex < 0 || _currentIndex >= _videos.length) return;
    
    try {
      if (_showingPreview.contains(_currentIndex) && 
          _previewControllers.containsKey(_currentIndex)) {
        await _previewControllers[_currentIndex]!.pause();
      } else if (_videoControllers.containsKey(_currentIndex)) {
        await _videoControllers[_currentIndex]!.pause();
      }
    } catch (e) {
      debugPrint('Error pausing current video: $e');
    }
  }
  
  /// Play the current video
  Future<void> playCurrentVideo() async {
    if (_currentIndex < 0 || _currentIndex >= _videos.length) return;
    
    try {
      if (_previewControllers.containsKey(_currentIndex) && 
          _previewControllers[_currentIndex]!.value.isInitialized &&
          !_videoControllers.containsKey(_currentIndex)) {
        // If only preview is available, show it
        await _previewControllers[_currentIndex]!.play();
        _showingPreview.add(_currentIndex);
      } else if (_videoControllers.containsKey(_currentIndex) && 
                _videoControllers[_currentIndex]!.value.isInitialized) {
        // If full video is available, use it
        await _videoControllers[_currentIndex]!.play();
        _showingPreview.remove(_currentIndex);
      }
    } catch (e) {
      debugPrint('Error playing current video: $e');
    }
  }
  
  /// Resume playback of current video (for app lifecycle handling)
  Future<void> resumeCurrentVideo() async {
    await playCurrentVideo();
  }
  
  /// Get the active controller for a specific index (either preview or full)
  VideoPlayerController? getControllerForIndex(int index) {
    if (_showingPreview.contains(index) && _previewControllers.containsKey(index)) {
      return _previewControllers[index];
    } else if (_videoControllers.containsKey(index)) {
      return _videoControllers[index];
    }
    return null;
  }
  
  /// Check if a video has had its first frame captured
  bool hasFirstFrame(int index) {
    if (index < 0 || index >= _videos.length) return false;
    return _videos[index].hasFirstFrame;
  }
  
  /// Get initialization future for a specific index
  Future<void>? getInitializationFutureForIndex(int index) {
    if (_showingPreview.contains(index) && _previewInitializationFutures.containsKey(index)) {
      return _previewInitializationFutures[index];
    } else if (_initializationFutures.containsKey(index)) {
      return _initializationFutures[index];
    }
    return null;
  }
  
  /// Checks if the device supports HEVC playback
  Future<bool> _isHevcSupported() async {
    // Force using AVC for now to avoid HEVC codec errors
    return false;
    
    // Original implementation
    /*
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
    */
  }
  
  /// Checks if the device is an emulator
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
  
  /// Determines the best video URL based on device capabilities
  Future<String> _getBestVideoUrl(VideoItem videoItem) async {
    final bool hevcSupported = await _isHevcSupported();
    final bool isRunningOnEmulator = await _isEmulator();
    
    // On emulators, forcibly use AVC regardless of API level
    final bool shouldUseHevc = hevcSupported && !isRunningOnEmulator;
    
    debugPrint('Device supports HEVC: $hevcSupported, Is emulator: $isRunningOnEmulator');
    
    // Choose URL based on device capability
    String videoUrl = shouldUseHevc ? videoItem.hevcUrl : videoItem.avcUrl;
    debugPrint('Selected video URL: $videoUrl');
    
    return videoUrl;
  }
  
  /// Dispose controller for a specific index
  void _disposeController(int index) {
    if (_videoControllers.containsKey(index)) {
      try {
        _videoControllers[index]!.dispose();
      } catch (e) {
        debugPrint('Error disposing video controller at index $index: $e');
      }
      _videoControllers.remove(index);
      _initializationFutures.remove(index);
    }
  }
  
  /// Dispose preview controller for a specific index
  void _disposePreviewController(int index) {
    if (_previewControllers.containsKey(index)) {
      try {
        _previewControllers[index]!.dispose();
      } catch (e) {
        debugPrint('Error disposing preview controller at index $index: $e');
      }
      _previewControllers.remove(index);
      _previewInitializationFutures.remove(index);
      _showingPreview.remove(index);
    }
  }
  
  /// Update the state and notify listeners
  void _updateState(ReelsState state) {
    _currentState = state;
    _stateController.add(state);
  }
  
  /// Handle page change events
  void onPageChanged(int index) {
    changeToIndex(index);
  }
  
  /// Handle scroll velocity for predictive preloading and buffer management
  void onScrollVelocity(double velocity) {
    _currentVelocity = velocity;
    
    // Adjust buffer size multiplier based on velocity
    // Slow drags (low velocity) -> larger buffer
    // Fast flings (high velocity) -> smaller buffer
    if (velocity.abs() < 100) {
      // Slow browsing - increase buffer size
      _bufferSizeMultiplier = 2.0;
    } else if (velocity.abs() > 500) {
      // Fast browsing - minimal buffer size
      _bufferSizeMultiplier = 0.5;
      
      // Also do predictive preloading
      final direction = velocity > 0 ? 1 : -1;
      final predictiveIndex = _currentIndex + (2 * direction);
      
      if (predictiveIndex >= 0 && predictiveIndex < _videos.length) {
        _preloadVideo(predictiveIndex);
      }
    } else {
      // Medium speed - normal buffer size
      _bufferSizeMultiplier = 1.0;
    }
  }
  
  /// Dispose resources
  void dispose() {
    // Dispose all video controllers
    for (final controller in _videoControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('Error disposing video controller: $e');
      }
    }
    _videoControllers.clear();
    _initializationFutures.clear();
    
    // Dispose all preview controllers
    for (final controller in _previewControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('Error disposing preview controller: $e');
      }
    }
    _previewControllers.clear();
    _previewInitializationFutures.clear();
    
    // Clear sets
    _showingPreview.clear();
    
    // Close the stream controller
    _stateController.close();
  }
}

/// Enum representing the state of the reels controller
enum ReelsState {
  loading,
  ready,
  error,
  indexChanged,
  videoSwapped,
} 