import 'package:bus_tracker_driver_app/screens/home_screen.dart';
import 'package:flutter/material.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _morphAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Define animations
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _morphAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Start animations
    _animationController.forward();

    // Schedule the transition to HomeScreen
    Future.delayed(const Duration(seconds: 4), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Loading screen content
          _buildLoadingScreen(),

          // Morphing effect overlay
          FadeTransition(
            opacity: _morphAnimation,
            child: _buildHomeMorph(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Image.asset(
                'assets/images/BUP_BUS_TRACKER_LOGO.png',
                width: 150.0,
                height: 150.0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: const Text(
              'Welcome to our app!',
              style: TextStyle(fontSize: 20.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeMorph() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Opacity(
          opacity: _morphAnimation.value,
          child: Text(
            'Welcome to the Home Screen!',
            style: TextStyle(
              fontSize: 20.0,
              color: Colors.green[900],
            ),
          ),
        ),
      ),
    );
  }
}
