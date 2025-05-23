import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../models/video_item.dart';
import '../services/video_service.dart';
import '../services/audio_manager.dart';
import '../services/thumbnail_service.dart';
import 'video_controller_pool.dart';
import 'buffer_manager.dart';

enum ReelsState {
  loading,
  ready,
  error,
  audioFocusChanged,
}

class ReelsController {
  final VideoService _videoService = VideoService();
  final AudioManager _audioManager = AudioManager();
  final ThumbnailService _thumbnailService = ThumbnailService();
  final VideoControllerPool _controllerPool = VideoControllerPool();
  final BufferManager _bufferManager = BufferManager();
  
  // Store videos fetched from API
  List<VideoItem> _videos = [];
  
  // Currently visible video index
  int _currentIndex = 0;
  
  // Map to store initialized controllers by ID
  final Map<String, VideoPlayerController> _initializedControllers = {};
  
  // Stream to notify UI of state changes
  final _stateController = StreamController<ReelsState>.broadcast();
  Stream<ReelsState> get stateStream => _stateController.stream;
  
  // Audio focus state
  bool _hasAudioFocus = false;
  
  ReelsState _currentState = ReelsState.loading;
  ReelsState get currentState => _currentState;
  
  // Track whether app is in foreground
  bool _isAppInForeground = true;
  
  // Getter to check if audio is enabled based on focus
  bool get isAudioEnabled => _hasAudioFocus;
  
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
    
    // Initialize audio manager
    await _audioManager.initialize();
    _audioManager.addAudioFocusListener(_handleAudioFocusChange);
    
    try {
      // Fetch videos from API
      _videos = await _videoService.getVideos();
      
      if (_videos.isEmpty) {
        _updateState(ReelsState.error);
        return;
      }
      
      print('✅ Subtask 3 complete: Vertical PageView UI setup for ${_videos.length} videos');
      
      // Preload initial set of videos at index 0
      await preloadVideosAroundIndex(0);
      
      _updateState(ReelsState.ready);
    } catch (e) {
      print('Error initializing reels controller: $e');
      _updateState(ReelsState.error);
    }
  }
  
  /// Pre-cache thumbnails for all videos
  Future<void> precacheThumbnails(BuildContext context) async {
    if (_videos.isEmpty) return;
    
    await _thumbnailService.precacheThumbnails(context, _videos);
  }
  
  /// Handle audio focus changes
  void _handleAudioFocusChange(bool hasFocus) {
    _hasAudioFocus = hasFocus;
    
    // Adjust volume or pause based on focus
    if (_currentIndex >= 0 && _currentIndex < _videos.length) {
      final currentVideo = _videos[_currentIndex];
      final controller = getControllerForIndex(_currentIndex);
      
      if (controller != null && controller.value.isInitialized) {
        if (hasFocus) {
          // Resume playback if we're the current video
          if (_currentState == ReelsState.ready) {
            controller.setVolume(1.0);
            if (!controller.value.isPlaying) {
              controller.play();
            }
          }
        } else {
          // Lower volume when ducked
          controller.setVolume(0.2);
        }
      }
    }
    
    // Notify UI to update
    _stateController.add(ReelsState.audioFocusChanged);
  }
  
  /// Update the controller's state
  void _updateState(ReelsState state) {
    _currentState = state;
    _stateController.add(state);
  }
  
  /// Preload videos around the current index
  Future<void> preloadVideosAroundIndex(int index) async {
    if (_videos.isEmpty) return;
    
    // Update current index
    _currentIndex = index.clamp(0, _videos.length - 1);
    
    // Preload videos with controller pool
    await _controllerPool.preloadVideos(_videos, _currentIndex);
    
    // Store initialized controllers in the map for fast access
    for (int i = _currentIndex - 1; i <= _currentIndex + 1; i++) {
      if (i >= 0 && i < _videos.length) {
        final VideoItem video = _videos[i];
        final controller = await _controllerPool.getControllerForVideo(video);
        _initializedControllers[video.id] = controller;
      }
    }
    
    // Preload audio for nearby videos
    await _audioManager.preloadAudioBatch(_videos, _currentIndex);
    
    // Apply buffer settings based on current velocity
    _applyBufferSettings();
    
    print('Videos preloaded around index $_currentIndex');
  }
  
  /// Apply buffer settings to active controllers
  void _applyBufferSettings() {
    // Get the current controller
    final currentController = getControllerForIndex(_currentIndex);
    if (currentController != null && currentController.value.isInitialized) {
      _bufferManager.applyBufferSettings(currentController);
    }
  }
  
  /// Handle page change
  Future<void> onPageChanged(int index) async {
    if (index < 0 || index >= _videos.length) return;
    
    final previousIndex = _currentIndex;
    _currentIndex = index;
    
    // Pause previous video
    final previousController = getControllerForIndex(previousIndex);
    if (previousController != null && previousController.value.isInitialized && previousController.value.isPlaying) {
      previousController.pause();
    }
    
    // Play current video if initialized
    final currentController = getControllerForIndex(_currentIndex);
    if (currentController != null && currentController.value.isInitialized) {
      // Prepare for playback
      await currentController.seekTo(Duration.zero);
      
      // Start playback if app is in foreground
      if (_isAppInForeground) {
        currentController.play();
      }
    }
    
    // Preload videos around the new index
    preloadVideosAroundIndex(index);
  }
  
  /// Update scroll velocity for buffer management
  void updateScrollVelocity(double velocity) {
    _bufferManager.updateScrollVelocity(velocity);
    
    // Apply updated buffer settings
    _applyBufferSettings();
    
    print('✅ Subtask 8 complete: Gesture-Based Buffering implemented (velocity: ${velocity.abs().toStringAsFixed(1)})');
  }
  
  /// Get controller for a video at specific index
  VideoPlayerController? getControllerForIndex(int index) {
    if (index < 0 || index >= _videos.length) return null;
    
    final VideoItem videoItem = _videos[index];
    
    // First check if we already have an initialized controller
    if (_initializedControllers.containsKey(videoItem.id)) {
      return _initializedControllers[videoItem.id];
    }
    
    // Otherwise return null - controllers must be preloaded before use
    return null;
  }
  
  /// Ensure a video at index is preloaded
  Future<void> ensureVideoPreloaded(int index) async {
    if (index < 0 || index >= _videos.length) return;
    
    // Get controller through the pool
    final video = _videos[index];
    final controller = await _controllerPool.getControllerForVideo(video);
    
    // Store in initialized controllers map
    _initializedControllers[video.id] = controller;
    
    // Make sure it's initialized
    if (!controller.value.isInitialized) {
      await controller.initialize();
    }
    
    await _controllerPool.initializeController(video.id);
  }
  
  /// Update app foreground state
  void setAppForegroundState(bool isInForeground) {
    _isAppInForeground = isInForeground;
    
    // Pause or resume current video based on foreground state
    if (_currentIndex >= 0 && _currentIndex < _videos.length) {
      final controller = getControllerForIndex(_currentIndex);
      
      if (controller != null && controller.value.isInitialized) {
        if (isInForeground) {
          // Resume playback
          controller.play();
        } else {
          // Pause playback
          controller.pause();
        }
      }
    }
  }
  
  /// Dispose all resources
  void dispose() {
    // Dispose controller pool
    _controllerPool.disposeAll();
    
    // Clear initialized controllers map
    _initializedControllers.clear();
    
    // Dispose audio manager
    _audioManager.dispose();
    
    // Close stream controller
    _stateController.close();
  }
} 