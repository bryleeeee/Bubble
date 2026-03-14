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
    // NEW: Gets the exact dimensions of whatever device this is running on
    final size = MediaQuery.of(context).size;

    return GestureDetector( 
      onTap: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const SignInScreen()),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4FAFF),
        body: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            children: [
              // --- RESPONSIVE BUBBLES (Uses percentages so it never leaves deadspace) ---
              Positioned(
                top: size.height * -0.1, 
                left: size.width * -0.3, 
                child: Image.asset('assets/images/blue_bubble.png', width: size.width * 1.2), 
              ),
              Positioned(
                top: size.height * -0.05,
                right: size.width * -0.2, 
                child: Image.asset('assets/images/pink_bubble.png', width: size.width * 0.8), 
              ),
              Positioned(
                bottom: size.height * -0.15, 
                left: size.width * -0.2, 
                child: Image.asset('assets/images/purple_bubble.png', width: size.width * 1.1), 
              ),
              Positioned(
                bottom: size.height * 0.25, 
                right: size.width * -0.2, 
                child: Image.asset('assets/images/yellow_bubble.png', width: size.width * 0.7), 
              ),
              Positioned(
                bottom: size.height * -0.05,
                right: size.width * -0.1, 
                child: Image.asset('assets/images/red_bubble.png', width: size.width * 0.5), 
              ),

              // --- GLOWING SPARKLES ---
              Positioned(top: size.height * 0.25, left: size.width * 0.25, child: Image.asset('assets/images/glitter.png', width: 60)),
              Positioned(top: size.height * 0.5, right: size.width * 0.15, child: Image.asset('assets/images/glitter.png', width: 45)),
              Positioned(bottom: size.height * 0.35, left: size.width * 0.3, child: Image.asset('assets/images/glitter.png', width: 55)),

              // --- 3D LOGO ---
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Image.asset('assets/images/Bubble_logo.png', width: 300), 
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}