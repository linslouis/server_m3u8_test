import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../controllers/reels_controller.dart';
import '../models/video_item.dart';
import 'reel_video_player.dart';

class ReelsPager extends StatefulWidget {
  const ReelsPager({Key? key}) : super(key: key);

  @override
  State<ReelsPager> createState() => _ReelsPagerState();
}

class _ReelsPagerState extends State<ReelsPager> with WidgetsBindingObserver {
  final ReelsController _reelsController = ReelsController();
  final PageController _pageController = PageController();
  
  // Track velocity for predictive preloading
  double _lastScrollVelocity = 0;
  
  // Track whether app is in foreground
  bool _isAppInForeground = true;
  
  // Track page transition for smooth frame animations
  double _currentPage = 0;
  bool _isScrolling = false;
  
  @override
  void initState() {
    super.initState();
    
    // Register for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    // Set preferred orientation to portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    
    // Initialize the reels controller
    _reelsController.initialize();
    
    // Listen for state changes
    _reelsController.stateStream.listen((state) {
      if (mounted) {
        if (state == ReelsState.ready || 
            state == ReelsState.indexChanged ||
            state == ReelsState.videoSwapped) {
          // Force rebuild when state changes
          setState(() {});
        }
      }
    });
    
    // Add listener to page controller for first frame transitions
    _pageController.addListener(_onPageScrollChange);
  }
  
  void _onPageScrollChange() {
    // Get the current page value
    final newPage = _pageController.page ?? 0;
    
    // Check if we're scrolling
    final isCurrentlyScrolling = newPage != newPage.round();
    
    // Only rebuild if:
    // 1. We weren't scrolling before but now we are, or
    // 2. We were scrolling before but now we're not, or
    // 3. The page value has changed significantly during scroll
    if ((_isScrolling != isCurrentlyScrolling) || 
        (isCurrentlyScrolling && (_currentPage - newPage).abs() > 0.01)) {
      setState(() {
        _currentPage = newPage;
        _isScrolling = isCurrentlyScrolling;
      });
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app going to background/foreground
    if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
      // Resume playback if app comes to foreground
      if (_reelsController.currentState == ReelsState.ready) {
        _reelsController.resumeCurrentVideo();
      }
    } else if (state == AppLifecycleState.paused) {
      _isAppInForeground = false;
      // Pause playback if app goes to background
      _reelsController.pauseCurrentVideo();
    }
  }
  
  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Remove page controller listener
    _pageController.removeListener(_onPageScrollChange);
    
    _pageController.dispose();
    _reelsController.dispose();
    
    // Reset orientation settings when done
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildContent(),
    );
  }
  
  Widget _buildContent() {
    // Show loading or error states
    if (_reelsController.currentState == ReelsState.loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    
    if (_reelsController.currentState == ReelsState.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Failed to load videos',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _reelsController.initialize(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    // Show video pager when ready
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: _reelsController.videos.length,
        onPageChanged: _onPageChanged,
        itemBuilder: _buildReelItem,
        // Add physics to control the paging behavior
        physics: const PageScrollPhysics().applyTo(const AlwaysScrollableScrollPhysics()),
      ),
    );
  }
  
  Widget _buildReelItem(BuildContext context, int index) {
    final VideoItem videoItem = _reelsController.videos[index];
    final bool isCurrentItem = index == _reelsController.currentIndex;
    
    // During page transitions, only show active video for the main page
    // For adjacent pages, show thumbnails/first frames to improve performance
    final bool shouldPlayVideo = !_isScrolling || 
        (_isScrolling && (_currentPage.round() == index));
        
    // Get controller for this index
    final VideoPlayerController? controller = 
        _reelsController.getControllerForIndex(index);
    
    // Get initialization future
    final Future<void>? initializationFuture = 
        _reelsController.getInitializationFutureForIndex(index);
    
    // If controller is not available, show placeholder
    if (controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    
    return FutureBuilder<void>(
      future: initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && 
            !snapshot.hasError && 
            controller.value.isInitialized) {
          
          // If we're in the middle of a swipe transition, show a paused frame
          // instead of a playing video, unless this is the current video
          if (_isScrolling && !shouldPlayVideo) {
            return _buildFirstFramePreview(controller);
          }
          
          // Auto-play video if it's the current item and app is in foreground
          if (isCurrentItem && shouldPlayVideo && _isAppInForeground && !controller.value.isPlaying) {
            controller.play();
          } else if (!shouldPlayVideo && controller.value.isPlaying) {
            // Pause if we're not supposed to be playing
            controller.pause();
          }
          
          return ReelVideoPlayer(
            videoItem: videoItem,
            controller: controller,
            isCurrentlyVisible: isCurrentItem && shouldPlayVideo,
          );
        } else {
          // Show loading or thumbnail placeholder
          return Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
      },
    );
  }
  
  /// Build a preview using the first frame of the video
  Widget _buildFirstFramePreview(VideoPlayerController controller) {
    // Make sure the controller is paused
    if (controller.value.isPlaying) {
      controller.pause();
    }
    
    // Create a thumbnail from the current paused frame
    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: VideoPlayer(controller),
    );
  }
  
  void _onPageChanged(int index) {
    // When page changes, tell controller to update the active video
    _reelsController.onPageChanged(index);
  }
  
  bool _handleScrollNotification(ScrollNotification notification) {
    // Track scroll velocity for predictive loading
    if (notification is ScrollUpdateNotification) {
      _lastScrollVelocity = notification.scrollDelta ?? 0;
      _reelsController.onScrollVelocity(_lastScrollVelocity);
    }
    
    // Detect when scrolling starts
    else if (notification is ScrollStartNotification) {
      // Set scrolling state to true
      setState(() {
        _isScrolling = true;
      });
    }
    
    // Detect when scrolling ends to adjust buffer based on final velocity
    else if (notification is ScrollEndNotification) {
      // Reset velocity
      _lastScrollVelocity = 0;
      
      // Update the scrolling state
      setState(() {
        _isScrolling = false;
      });
    }
    
    return false; // Continue dispatching notification
  }
} 