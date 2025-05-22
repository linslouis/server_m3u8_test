# Short Video Feed App

A Flutter application that implements a TikTok/Reels/Shorts style vertical video feed with advanced HLS streaming and performance optimizations.

## Features

- **Vertical swipeable feed** with fullscreen videos
- **HLS adaptive bitrate streaming** (480p/720p/1080p) that auto-switches based on bandwidth
- **Preview clips with seamless transition**:
  - First loads 5-second preview at 720p
  - Simultaneously downloads full video in background
  - Seamlessly transitions at segment boundary
- **Intelligent preloading**:
  - Preloads ±2 videos around current index
  - Uses predictive prefetch based on scroll velocity
- **Hardware decoder pooling**:
  - Maintains limited pool of decoders to avoid re-initialization stalls
  - Prioritizes closest videos when managing the pool
- **Smart buffer management**:
  - Adjusts buffer size based on scroll velocity
  - Deeper prebuffer on slow drags, minimal on quick flings
- **Performance optimizations**:
  - Efficiently swaps between preview and full video
  - Handles orientation changes and device capabilities
  - Supports both HEVC (H.265) and AVC (H.264) formats

## Implementation Details

The app uses a modular architecture with the following components:

- **VideoItem**: Data model for video metadata
- **VideoFeedService**: Handles API calls to fetch the video feed
- **ReelsController**: Core controller that manages:
  - Video preloading strategy
  - Preview/full video swapping
  - Decoder instance pooling
  - Buffer size adjustments
- **ReelsPager**: Main UI widget with vertical PageView
- **ReelVideoPlayer**: Individual video player component

## Technical Considerations

- **Adaptive Streaming**: The app uses HLS (HTTP Live Streaming) to adapt video quality based on network conditions
- **Codec Selection**: Automatically selects HEVC (H.265) on supported devices, falling back to AVC (H.264) on older devices
- **Emulator Detection**: Forcibly uses AVC on emulators regardless of API level
- **Memory Management**: Limits the number of simultaneous decoder instances to prevent OOM issues
- **Segment Boundary Detection**: Intelligently detects segment boundaries for seamless transitions

## Requirements

- Flutter 3.7+
- iOS 11+ or Android API 21+
- For HEVC support: iOS 11+ or Android API 29+

## License

This project is open-source and available under the MIT License.
