import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/page_transitions.dart';
import 'permissions_onboarding_screen.dart';
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late VideoPlayerController _videoController;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // The 3 info texts for your carousel
  final List<String> _infoTexts = [
    "Coordinate seamlessly with your convoy on any road trip",
    "Share your location and vehicle status in real-time",
    "Propose democratic halts and trigger smart SOS alerts"
  ];

  @override
  void initState() {
    super.initState();
    // Initialize the background video
    _videoController = VideoPlayerController.asset('assets/videos/road_loop_480.mp4')
      ..initialize().then((_) {
        _videoController.setVolume(0.0); // Mute video
        _videoController.setLooping(true);
        _videoController.play();
        setState(() {});
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    // Save to SharedPreferences so they don't see this again
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        FadeSlideRoute(page: const PermissionsOnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access the global typography theme
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Video Layer
          if (_videoController.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController.value.size.width,
                height: _videoController.value.size.height,
                child: VideoPlayer(_videoController),
              ),
            ),

          // 2. Dark Gradient Overlay (Makes text readable against the video)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // 3. UI Layer
          SafeArea(
            child: Column(
              children: [
                // Top Logo - Nudged upwards
                Transform.translate(
                  offset: const Offset(0, 5), // The negative Y value pulls it UP
                  child: Image.asset(
                    'assets/images/app_logo_white.png',
                    height: 80, // Slightly reduced so the invisible padding doesn't take up too much room
                  ),
                ),

                const Spacer(), // Pushes everything else to the bottom

                // Swipeable Text Area
                SizedBox(
                  height: 100,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    itemCount: _infoTexts.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          _infoTexts[index],
                          textAlign: TextAlign.center,
                          // Applied Thicccboi from the theme here:
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // 3 Dots Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _infoTexts.length,
                        (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentPage == index ? 8 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? Colors.white : Colors.white.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Get Started Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: ElevatedButton(
                    onPressed: _completeOnboarding,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5CB85C), // Primary green
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      "Get started",
                      // Applied Thicccboi from the theme here:
                      style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}