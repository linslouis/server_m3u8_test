import 'package:flutter/material.dart';

class VideoItem {
  final String id;
  final Map<String, String> playlists;
  final String? thumbnail;
  
  // Store the first frame as a memory image once extracted
  ImageProvider? firstFrameImage;
  bool hasFirstFrame = false;
  
  VideoItem({
    required this.id,
    required this.playlists,
    this.thumbnail,
  });
  
  /// Creates a video from JSON data
  factory VideoItem.fromJson(Map<String, dynamic> json) {
    // Handle id that can be either String or int
    final dynamic rawId = json['id'];
    final String id = rawId is String ? rawId : rawId.toString();
    
    return VideoItem(
      id: id,
      playlists: Map<String, String>.from(json['playlists'] as Map),
      thumbnail: json['thumbnail'] as String?,
    );
  }
  
  /// Gets the AVC (H.264) playlist URL
  String get avcUrl => playlists['avc'] ?? '';
  
  /// Gets the HEVC (H.265) playlist URL
  String get hevcUrl => playlists['hevc'] ?? '';
} 