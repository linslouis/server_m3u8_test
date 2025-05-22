/// Represents a video with different encoding formats
class Video {
  final int id;
  final Map<String, String> playlists;
  
  const Video({
    required this.id,
    required this.playlists,
  });
  
  /// Creates a video from JSON data
  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'] as int,
      playlists: Map<String, String>.from(json['playlists'] as Map),
    );
  }
  
  /// Gets the AVC (H.264) playlist URL
  String get avcUrl => playlists['avc'] ?? '';
  
  /// Gets the HEVC (H.265) playlist URL
  String get hevcUrl => playlists['hevc'] ?? '';
} 