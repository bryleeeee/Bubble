import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rant_app/login.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Keeps the whole screen tap-to-continue
    return GestureDetector( 
      onTap: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const SignInScreen()),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4FAFF),
        body: Stack(
          children: [
          // --- THE SUPER SIZED BUBBLES ---
          Positioned(
            top: -120, 
            left: -150, 
            child: Image.asset('assets/images/blue_bubble.png', width: 450), 
          ),
          Positioned(
            top: -80,
            right: -120, 
            child: Image.asset('assets/images/pink_bubble.png', width: 320), 
          ),
          Positioned(
            bottom: -150, 
            left: -100, 
            child: Image.asset('assets/images/purple_bubble.png', width: 420), 
          ),
          Positioned(
            bottom: 220, 
            right: -100, 
            child: Image.asset('assets/images/yellow_bubble.png', width: 280), 
          ),
          Positioned(
            bottom: -50,
            right: 80, 
            child: Image.asset('assets/images/red_bubble.png', width: 180), 
          ),

          // --- THE GLOWING SPARKLES ---
          Positioned(top: 200, left: 100, child: Image.asset('assets/images/glitter.png', width: 60)),
          Positioned(top: 450, right: 60, child: Image.asset('assets/images/glitter.png', width: 45)),
          Positioned(bottom: 280, left: 120, child: Image.asset('assets/images/glitter.png', width: 55)),

          // --- THE 3D LOGO ---
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Image.asset('assets/images/Bubble_logo.png', width: 300), 
            ),
          ),
          ],
        ),
      ),
    );
  }
}