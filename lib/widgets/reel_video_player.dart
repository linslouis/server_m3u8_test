import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/video_item.dart';

/// Displays a video with thumbnail fallback
class ReelVideoPlayer extends StatefulWidget {
  final VideoItem videoItem;
  final VideoPlayerController? controller;
  final bool isVisible;
  final bool isScrolling;
  final double position;
  final VoidCallback onTap;
  
  const ReelVideoPlayer({
    Key? key,
    required this.videoItem,
    required this.controller,
    required this.isVisible,
    required this.isScrolling,
    required this.position,
    required this.onTap,
  }) : super(key: key);

  @override
  State<ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<ReelVideoPlayer> {
  bool _showThumbnail = true;
  bool _controlsVisible = false;
  bool _isInitialized = false;
  
  @override
  void initState() {
    super.initState();
    _initializeController();
  }
  
  @override
  void didUpdateWidget(ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If controller changed, reinitialize
    if (oldWidget.controller != widget.controller) {
      _initializeController();
    }
    
    // Check visibility changes
    if (oldWidget.isVisible != widget.isVisible ||
        oldWidget.isScrolling != widget.isScrolling) {
      _updatePlaybackState();
    }
  }
  
  void _initializeController() {
    setState(() {
      _showThumbnail = true;
      _isInitialized = false;
    });
    
    if (widget.controller != null) {
      // Check if already initialized
      if (widget.controller!.value.isInitialized) {
        setState(() {
          _isInitialized = true;
          _showThumbnail = false;
        });
        
        // Update playback state
        _updatePlaybackState();
      } else {
        // Initialize and set up listener
        widget.controller!.initialize().then((_) {
          if (mounted) {
            setState(() {
              _isInitialized = true;
              
              // Keep thumbnail visible briefly to ensure smooth transition
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  setState(() {
                    _showThumbnail = false;
                  });
                }
              });
            });
            
            _updatePlaybackState();
          }
        }).catchError((error) {
          print('Error initializing video controller: $error');
          // Keep showing thumbnail
          if (mounted) {
            setState(() {
              _showThumbnail = true;
            });
          }
        });
      }
      
      // Set up value listener for initialization state
      widget.controller!.addListener(_controllerListener);
    }
  }
  
  void _controllerListener() {
    if (widget.controller != null && 
        widget.controller!.value.isInitialized && 
        !_isInitialized) {
      setState(() {
        _isInitialized = true;
      });
    }
  }
  
  void _updatePlaybackState() {
    if (widget.controller == null || !widget.controller!.value.isInitialized) {
      return;
    }
    
    if (widget.isVisible && !widget.isScrolling) {
      // This is the focused video, play it
      if (!widget.controller!.value.isPlaying) {
        widget.controller!.play();
      }
    } else {
      // Not visible or scrolling, pause to save resources
      if (widget.controller!.value.isPlaying) {
        widget.controller!.pause();
      }
    }
  }
  
  @override
  void dispose() {
    if (widget.controller != null) {
      widget.controller!.removeListener(_controllerListener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video or thumbnail
            _buildMainContent(),
            
            // Gradient overlay for better visibility
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                    ],
                    stops: const [0.0, 0.15, 0.85, 1.0],
                  ),
                ),
              ),
            ),
            
            // Video controls
            if (_controlsVisible)
              _buildControls(),
              
            // Video info
            _buildVideoInfo(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMainContent() {
    // If controller is initialized and we're not showing thumbnail, show video
    if (!_showThumbnail && 
        widget.controller != null && 
        widget.controller!.value.isInitialized) {
      return _buildVideoPlayer();
    }
    
    // Otherwise show thumbnail
    return _buildThumbnail();
  }
  
  Widget _buildVideoPlayer() {
    return Center(
      child: AspectRatio(
        aspectRatio: widget.controller!.value.aspectRatio,
        child: VideoPlayer(widget.controller!),
      ),
    );
  }
  
  Widget _buildThumbnail() {
    if (widget.videoItem.thumbnail != null && widget.videoItem.thumbnail!.isNotEmpty) {
      return Center(
        child: CachedNetworkImage(
          imageUrl: widget.videoItem.thumbnail!,
          fit: BoxFit.contain,
          placeholder: (context, url) => Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.black,
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.white, size: 48),
            ),
          ),
        ),
      );
    } else {
      // Fallback colored placeholder
      return Container(
        color: Colors.grey.shade900,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
      );
    }
  }
  
  Widget _buildControls() {
    return Stack(
      children: [
        // Play/Pause button centered
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              iconSize: 50,
              icon: Icon(
                widget.controller?.value.isPlaying ?? false 
                    ? Icons.pause 
                    : Icons.play_arrow,
                color: Colors.white,
              ),
              onPressed: _togglePlayPause,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildVideoInfo() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.videoItem.title != null) 
            Text(
              widget.videoItem.title!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (widget.videoItem.author != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                widget.videoItem.author!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  void _onTap() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    
    widget.onTap();
    
    // Auto-hide controls after a delay
    if (_controlsVisible) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _controlsVisible = false;
          });
        }
      });
    }
  }
  
  void _togglePlayPause() {
    if (widget.controller == null) return;
    
    if (widget.controller!.value.isPlaying) {
      widget.controller!.pause();
    } else {
      widget.controller!.play();
    }
  }
} 