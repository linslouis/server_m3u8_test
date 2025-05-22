import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video_item.dart';

class ReelVideoPlayer extends StatelessWidget {
  final VideoItem videoItem;
  final VideoPlayerController controller;
  final bool isCurrentlyVisible;

  const ReelVideoPlayer({
    Key? key,
    required this.videoItem,
    required this.controller,
    required this.isCurrentlyVisible,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video player
        _buildVideoPlayer(),
        
        // Touch overlay to toggle play/pause
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
            },
          ),
        ),
        
        // Optional video controls, indicators, etc.
        Positioned(
          bottom: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                // Calculate buffer progress
                double bufferProgress = 0.0;
                if (value.buffered.isNotEmpty) {
                  final Duration bufferedEnd = value.buffered.last.end;
                  bufferProgress = bufferedEnd.inMilliseconds / 
                      (value.duration.inMilliseconds == 0 ? 1 : value.duration.inMilliseconds);
                }
                
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDuration(value.position),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    const Text(
                      ' / ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _formatDuration(value.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 50,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Stack(
                        children: [
                          // Buffer progress
                          FractionallySizedBox(
                            widthFactor: bufferProgress,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          // Playback progress
                          FractionallySizedBox(
                            widthFactor: value.duration.inMilliseconds > 0
                                ? value.position.inMilliseconds / value.duration.inMilliseconds
                                : 0.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
  
  /// Build the video player with efficient rendering
  Widget _buildVideoPlayer() {
    if (!controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
} 