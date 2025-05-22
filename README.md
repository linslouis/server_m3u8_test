# Flutter HLS Video Player

A production-ready Flutter application that demonstrates how to implement HTTP Live Streaming (HLS) video playback using Flutter's video_player package.

## Features

- Seamless HLS video playback with adaptive bitrate streaming
- Clean, responsive UI with loading states
- Proper error handling with retry functionality
- Play/pause control with visual feedback
- Maintains video aspect ratio for proper display
- Handles lifecycle events (initialization, playback, disposal)

## Technology Stack

- **Flutter:** UI framework for cross-platform development
- **video_player:** Plugin for video playback (uses ExoPlayer on Android, AVPlayer on iOS)
- **HTTP Live Streaming (HLS):** Streaming protocol that adapts to network conditions

## Implementation Details

The application uses a single master HLS playlist URL which contains multiple quality levels. The underlying native players (ExoPlayer on Android, AVPlayer on iOS) automatically handle quality switching based on network conditions through Adaptive Bitrate Streaming.

The player is implemented as a StatefulWidget that:
- Initializes the video controller in `initState()`
- Properly configures looping and autoplay
- Provides a clean UI for loading, playback, and error states
- Handles proper resource disposal

## Getting Started

1. Ensure Flutter is installed on your development machine
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Connect a device or start an emulator
5. Run `flutter run` to launch the application

## Project Structure

- `lib/main.dart`: Contains the main application code and HLS player implementation
- `pubspec.yaml`: Defines project dependencies including the video_player package

## Requirements

- Flutter 3.0.0 or higher
- Dart 2.17.0 or higher
- Android 4.4+ or iOS 11.0+ for device compatibility

## License

This project is open-source and available under the MIT License.
