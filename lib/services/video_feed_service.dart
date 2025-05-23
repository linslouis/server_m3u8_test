import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_item.dart';

class VideoFeedService {
  static const String _apiUrl = 'https://raw.githubusercontent.com/linslouis/server_m3u8_test/refs/heads/video_list_pager/assets/test_video_list_api.json';
  static const String _cacheKey = 'video_feed_cache';
  static const Duration _cacheDuration = Duration(hours: 1);
  
  // Singleton instance
  static final VideoFeedService _instance = VideoFeedService._internal();
  factory VideoFeedService() => _instance;
  VideoFeedService._internal();
  
  // Cache the last fetch time
  DateTime? _lastFetchTime;
  
  // Cache the videos to avoid repeated fetches
  List<VideoItem>? _cachedVideos;
  
  /// Fetches the video feed from the API or cache
  Future<List<VideoItem>> fetchVideoFeed({bool forceRefresh = false}) async {
    // Return cached videos if available and not forced to refresh
    if (!forceRefresh && _cachedVideos != null && _lastFetchTime != null) {
      final cacheAge = DateTime.now().difference(_lastFetchTime!);
      if (cacheAge < _cacheDuration) {
        debugPrint('Using in-memory cached video feed (${_cachedVideos!.length} items)');
        return _cachedVideos!;
      }
    }
    
    try {
      // Try to load from persistent cache first
      if (!forceRefresh) {
        final cachedData = await _loadFromCache();
        if (cachedData != null) {
          debugPrint('Using disk-cached video feed (${cachedData.length} items)');
          _cachedVideos = cachedData;
          _lastFetchTime = DateTime.now();
          return cachedData;
        }
      }
      
      // Make network request with timeout
      final response = await http.get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);
        
        // Process based on actual JSON structure
        List<VideoItem> videos = [];
        
        if (decodedData is Map<String, dynamic> && decodedData.containsKey('videos')) {
          // Format: {"videos": [...]}
          final List<dynamic> videosJson = decodedData['videos'] as List<dynamic>;
          videos = videosJson.map((item) => VideoItem.fromJson(item as Map<String, dynamic>)).toList();
        } 
        else if (decodedData is List<dynamic>) {
          // Format: [...]
          videos = decodedData.map((item) => VideoItem.fromJson(item as Map<String, dynamic>)).toList();
        }
        else {
          throw Exception('Unexpected JSON format: expected a Map with "videos" key or a List');
        }
        
        // Cache the results
        _saveToCache(videos);
        _cachedVideos = videos;
        _lastFetchTime = DateTime.now();
        
        debugPrint('Successfully fetched ${videos.length} videos from network');
        
        // Verify we have the expected fields for at least the first item
        if (videos.isNotEmpty) {
          assert(videos[0].id.isNotEmpty, 'First video has empty ID');
          assert(videos[0].avcUrl.isNotEmpty, 'First video has empty AVC URL');
          debugPrint('Verification: First video ID: ${videos[0].id}, AVC URL: ${videos[0].avcUrl}');
        }
        
        return videos;
      } else {
        throw Exception('Failed to load video feed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching video feed: $e');
      
      // If we have cached data, return that as fallback
      if (_cachedVideos != null) {
        debugPrint('Falling back to cached data due to error');
        return _cachedVideos!;
      }
      
      throw Exception('Error fetching video feed: $e');
    }
  }
  
  /// Loads cached video feed from persistent storage
  Future<List<VideoItem>?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_cacheKey);
      
      if (jsonString == null) return null;
      
      // Parse cache metadata (first line is timestamp)
      final lines = jsonString.split('\n');
      if (lines.length < 2) return null;
      
      final timestamp = int.tryParse(lines[0]);
      if (timestamp == null) return null;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final cacheAge = DateTime.now().difference(cacheTime);
      
      // Return null if cache is too old
      if (cacheAge > _cacheDuration) return null;
      
      // Parse the actual data (rest of the string)
      final dataJson = lines.sublist(1).join('\n');
      final List<dynamic> decodedData = json.decode(dataJson) as List<dynamic>;
      
      return decodedData
          .map((item) => VideoItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading from cache: $e');
      return null;
    }
  }
  
  /// Saves video feed to persistent cache
  Future<void> _saveToCache(List<VideoItem> videos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Extract just the necessary data to reduce cache size
      final List<Map<String, dynamic>> simplifiedData = videos.map((video) => {
        'id': video.id,
        'thumbnail': video.thumbnail,
        'playlists': video.playlists,
      }).toList();
      
      // Add timestamp as first line
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final jsonData = json.encode(simplifiedData);
      final dataToSave = '$timestamp\n$jsonData';
      
      await prefs.setString(_cacheKey, dataToSave);
      debugPrint('Saved ${videos.length} videos to cache');
    } catch (e) {
      debugPrint('Error saving to cache: $e');
      // Non-fatal error, just log it
    }
  }
  
  /// Clears the cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      _cachedVideos = null;
      _lastFetchTime = null;
      debugPrint('Cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
} 