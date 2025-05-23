import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:typed_data';  // Add import for Uint8List

/// Represents a video item in the feed
class VideoItem {
  final String id;
  final Map<String, String> playlists;
  String? thumbnail;  // Non-final to allow setting later
  
  // Additional metadata
  final String? title;
  final String? author;
  final int? likes;
  final int? comments;
  final int? shares;
  
  // First frame tracking
  ImageProvider? firstFrameImage;
  bool hasFirstFrame = false;
  bool attemptedFirstFrameExtraction = false;
  
  // Playback state
  double bufferProgress = 0.0;  // 0.0 to 1.0
  
  VideoItem({
    required this.id,
    required this.playlists,
    this.thumbnail,
    this.title,
    this.author,
    this.likes,
    this.comments,
    this.shares,
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
      title: json['title'] as String?,
      author: json['author'] as String?,
      likes: json['likes'] as int?,
      comments: json['comments'] as int?,
      shares: json['shares'] as int?,
    );
  }
  
  /// Gets the AVC (H.264) playlist URL
  String get avcUrl => playlists['avc'] ?? '';
  
  /// Gets the HEVC (H.265) playlist URL
  String get hevcUrl => playlists['hevc'] ?? '';
  
  /// Gets a thumbnail image provider, either from URL or first frame
  ImageProvider get thumbnailProvider {
    if (firstFrameImage != null) {
      return firstFrameImage!;
    } else if (thumbnail != null && thumbnail!.isNotEmpty) {
      return NetworkImage(thumbnail!);
    } else {
      // Fallback to a colored placeholder
      return MemoryImage(_generateColoredPlaceholder());
    }
  }
  
  /// Generate a colored placeholder image based on the video ID
  Uint8List _generateColoredPlaceholder() {
    // Create a unique color based on the video ID
    final int colorValue = id.hashCode & 0xFFFFFF;
    final Color color = Color(0xFF000000 | colorValue);
    
    // Create a simple 1x1 placeholder image with that color
    final Uint8List buffer = Uint8List(4); // RGBA
    buffer[0] = color.red.toInt();
    buffer[1] = color.green.toInt();
    buffer[2] = color.blue.toInt();
    buffer[3] = 255; // Alpha (fully opaque)
    
    return buffer;
  }
  
  /// Mark that first frame extraction has been attempted
  void markFirstFrameAttempted() {
    attemptedFirstFrameExtraction = true;
  }
  
  /// Set the first frame image
  void setFirstFrame(ImageProvider image) {
    firstFrameImage = image;
    hasFirstFrame = true;
    attemptedFirstFrameExtraction = true;
  }
  
  /// Update buffer progress
  void updateBufferProgress(double progress) {
    bufferProgress = progress.clamp(0.0, 1.0);
  }
} 