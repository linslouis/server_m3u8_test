import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:video_player/video_player.dart' as video;
import '../models/video.dart';

/// Controller to manage video playback and format selection logic
class HlsPlayerController {
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  
  // For demonstration - in a real app, this would come from an API
  final Video _demoVideo = Video(
    id: 123,
    playlists: {
      'avc': 'https://raw.githubusercontent.com/linslouis/server_m3u8_test/master/assets/hls-output/master.m3u8',
      'hevc': 'https://raw.githubusercontent.com/linslouis/server_m3u8_test/master/assets/hls-output-hevc/master.m3u8',
    },
  );
  
  /// Returns the demo video
  Video get demoVideo => _demoVideo;
  
  /// Checks if the device supports HEVC playback
  Future<bool> isHevcSupported() async {
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
  
  /// Checks if the device is an emulator
  Future<bool> isEmulator() async {
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
  Future<String> getBestVideoUrl() async {
    final bool hevcSupported = await isHevcSupported();
    final bool isRunningOnEmulator = await isEmulator();
    
    // On emulators, forcibly use AVC regardless of API level
    final bool shouldUseHevc = hevcSupported && !isRunningOnEmulator;
    
    debugPrint('Device supports HEVC: $hevcSupported, Is emulator: $isRunningOnEmulator');
    
    // Choose URL based on device capability
    String videoUrl = shouldUseHevc ? _demoVideo.hevcUrl : _demoVideo.avcUrl;
    debugPrint('Selected video URL: $videoUrl');
    
    return videoUrl;
  }
  
  /// Creates a video player instance with the optimal format
  Future<video.VideoPlayerController> createVideoPlayerController() async {
    final url = await getBestVideoUrl();
    
    return video.VideoPlayerController.networkUrl(
      Uri.parse(url),
      formatHint: video.VideoFormat.hls,
    );
  }
} 