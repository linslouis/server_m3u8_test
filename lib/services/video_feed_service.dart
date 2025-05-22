import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/video_item.dart';
import 'package:flutter/foundation.dart';

class VideoFeedService {
  static const String _apiUrl = 'https://raw.githubusercontent.com/linslouis/server_m3u8_test/refs/heads/video_list_pager/assets/test_video_list_api.json';
  
  /// Fetches the video feed from the API
  Future<List<VideoItem>> fetchVideoFeed() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      
      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);
        
        // Based on actual JSON structure, it's a Map with a "videos" key
        if (decodedData is Map<String, dynamic> && decodedData.containsKey('videos')) {
          final List<dynamic> videos = decodedData['videos'] as List<dynamic>;
          return videos.map((item) => VideoItem.fromJson(item as Map<String, dynamic>)).toList();
        } 
        // Fallback in case the structure changes
        else if (decodedData is List<dynamic>) {
          return decodedData.map((item) => VideoItem.fromJson(item as Map<String, dynamic>)).toList();
        }
        else {
          debugPrint('Unexpected JSON format: ${decodedData.runtimeType}');
          throw Exception('Unexpected JSON format: expected a Map with "videos" key or a List');
        }
      } else {
        throw Exception('Failed to load video feed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching video feed: $e');
      throw Exception('Error fetching video feed: $e');
    }
  }
} 