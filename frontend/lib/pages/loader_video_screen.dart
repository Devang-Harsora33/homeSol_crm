import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart'; // For status bar color
import 'dart:async'; // Import for Timer

class LoaderVideoScreen extends StatefulWidget {
  final VoidCallback? onSkip; // New callback

  const LoaderVideoScreen({super.key, this.onSkip}); // Modified constructor

  @override
  State<LoaderVideoScreen> createState() => _LoaderVideoScreenState();
}

class _LoaderVideoScreenState extends State<LoaderVideoScreen> {
  late VideoPlayerController _controller;
  bool _allowSkipTap = false; // New state to control when taps can skip
  Timer? _skipTapTimer;
  Timer? _autoSkipTimer; // Timer for 6-second auto-skip

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset(
      'assets/videos/loader.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )
      ..setLooping(true) // Loop to cover the 6 seconds
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.play();
        }
      });

    // Start a timer to allow skipping after a small delay (0.5s)
    _skipTapTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _allowSkipTap = true;
        });
      }
    });

    // Auto-skip after 6 seconds
    _autoSkipTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        widget.onSkip?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _skipTapTimer?.cancel();
    _autoSkipTimer?.cancel(); // Cancel the auto-skip timer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Your requested color
      body: GestureDetector(
        onTap: _allowSkipTap && widget.onSkip != null ? widget.onSkip : null,
        child: Stack( // Use Stack to layer video
          children: [
            Center(
              child: _controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}