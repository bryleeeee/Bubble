import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart'; 
import 'sign_up.dart'; 

// ============================================================================
// LOCAL THEME 
// ============================================================================
class LocalTheme {
  static const Color textPrimary   = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary  = Color(0xFFADB5BD);
  static const Color inputBorder   = Color(0xFFE4E9F0);
  static const Color pastelPurple  = Color(0xFFCFB8E8);
  static const Color pastelPink    = Color(0xFFFFB3C8);
  static const Color pastelBlue    = Color(0xFFADD4EC);
  static const Color pastelYellow  = Color(0xFFFFF0A0);
  static const Color divider       = Color(0xFFF0F0F5);
}

// ============================================================================
// SIGN IN SCREEN 
// ============================================================================
class SignInScreen extends StatefulWidget {
  const SignInScreen({Key? key}) : super(key: key);

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure       = true;
  bool _loading       = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // --- NEW: FIREBASE SIGN IN LOGIC ---
  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields')));
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _loading = true);
    
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // Shows Firebase errors (e.g. wrong password, user not found) nicely to the user
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message ?? 'Authentication failed'),
        backgroundColor: Colors.redAccent,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAFF), 
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned(top: -120, left: -150, child: Image.asset('assets/images/blue_bubble.png', width: 450)),
          Positioned(top: -80, right: -120, child: Image.asset('assets/images/pink_bubble.png', width: 320)),
          Positioned(bottom: -150, left: -100, child: Image.asset('assets/images/purple_bubble.png', width: 420)),
          Positioned(bottom: 220, right: -100, child: Image.asset('assets/images/yellow_bubble.png', width: 280)),
          Positioned(bottom: -50, right: 80, child: Image.asset('assets/images/red_bubble.png', width: 180)),

          Positioned(top: 200, left: 100, child: Image.asset('assets/images/glitter.png', width: 60)),
          Positioned(top: 450, right: 60, child: Image.asset('assets/images/glitter.png', width: 45)),
          Positioned(bottom: 280, left: 120, child: Image.asset('assets/images/glitter.png', width: 55)),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {}, 
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 10)],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: LocalTheme.textPrimary, size: 16),
                    ),
                  ),
                  const SizedBox(height: 36),

                  Center(
                    child: Column(children: [
                      Image.asset('assets/images/Bubble_logo.png', height: 60),
                      const SizedBox(height: 10),
                      const Text(
                        'Welcome back ✦',
                        style: TextStyle(fontSize: 14, color: LocalTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 40),

                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9), 
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(color: LocalTheme.pastelBlue.withOpacity(0.18), blurRadius: 30, offset: const Offset(0, 8)),
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sign In', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: LocalTheme.textPrimary, letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        const Text('Please enter your details to continue', style: TextStyle(fontSize: 13, color: LocalTheme.textSecondary, fontWeight: FontWeight.w400)),
                        const SizedBox(height: 24),

                        _LoginField(
                          controller: _emailCtrl, label: 'Email',
                          hint: 'you@example.com', icon: Icons.mail_outline_rounded, 
                          keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),

                        _LoginField(
                          controller: _passwordCtrl, label: 'Password',
                          hint: '••••••••', icon: Icons.lock_outline_rounded, 
                          obscureText: _obscure, textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _signIn(),
                          suffixIcon: GestureDetector(
                            onTap: () => setState(() => _obscure = !_obscure),
                            child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: LocalTheme.textTertiary, size: 20),
                          ),
                        ),
                        const SizedBox(height: 10),
                        
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () {},
                            child: const Text('Forgot Password?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: LocalTheme.pastelPurple, decoration: TextDecoration.underline, decorationColor: LocalTheme.pastelPurple)),
                          ),
                        ),
                        const SizedBox(height: 26),

                        _LoginButton(
                          label: 'Sign In',
                          loading: _loading,
                          onTap: _signIn,
                        ),
                        const SizedBox(height: 20),
                        
                        Row(children: [
                          const Expanded(child: Divider(color: LocalTheme.divider, thickness: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or', style: TextStyle(color: LocalTheme.textTertiary, fontSize: 12, fontWeight: FontWeight.w500)),
                          ),
                          const Expanded(child: Divider(color: LocalTheme.divider, thickness: 1)),
                        ]),
                        const SizedBox(height: 20),

                        _LoginButton(
                          label: 'Create Account',
                          outlined: true, 
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen()));
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        Center(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 13, color: LocalTheme.textSecondary),
                              children: [
                                const TextSpan(text: "Don't have an account?  "),
                                WidgetSpan(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen()));
                                    },
                                    child: const Text('Sign Up', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: LocalTheme.textPrimary, decoration: TextDecoration.underline)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const HomeScreen()));
                      },
                      child: const Text('Continue without Signing in', style: TextStyle(fontSize: 13, color: LocalTheme.textSecondary, fontWeight: FontWeight.w500, decoration: TextDecoration.underline, decorationColor: LocalTheme.textTertiary)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SELF-CONTAINED WIDGETS
// ============================================================================

class _LoginField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final Widget? suffixIcon;

  const _LoginField({
    required this.controller, required this.label, required this.hint, 
    required this.icon, this.obscureText = false, this.keyboardType, 
    this.textInputAction, this.onSubmitted, this.suffixIcon, Key? key
  }) : super(key: key);

  @override
  State<_LoginField> createState() => _LoginFieldState();
}

class _LoginFieldState extends State<_LoginField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _focused ? LocalTheme.pastelPurple : LocalTheme.textSecondary, letterSpacing: 0.3)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _focused ? LocalTheme.pastelPurple : LocalTheme.inputBorder, width: _focused ? 1.8 : 1.2),
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          Icon(widget.icon, color: _focused ? LocalTheme.pastelPurple : LocalTheme.textTertiary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Focus(
              onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
              child: TextField(
                controller: widget.controller, obscureText: widget.obscureText, 
                keyboardType: widget.keyboardType, textInputAction: widget.textInputAction, 
                onSubmitted: widget.onSubmitted,
                style: const TextStyle(fontSize: 14.5, color: LocalTheme.textPrimary, fontWeight: FontWeight.w500),
                decoration: InputDecoration(hintText: widget.hint, hintStyle: const TextStyle(color: LocalTheme.textTertiary, fontSize: 14), border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ),
          if (widget.suffixIcon != null) ...[widget.suffixIcon!, const SizedBox(width: 12)],
        ]),
      ),
    ]);
  }
}

class _LoginButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool loading;
  final bool outlined;

  const _LoginButton({required this.label, required this.onTap, this.loading = false, this.outlined = false, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity, height: 52,
        decoration: outlined 
          ? BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(30), border: Border.all(color: LocalTheme.pastelPurple, width: 1.8))
          : BoxDecoration(gradient: const LinearGradient(colors: [LocalTheme.pastelPink, LocalTheme.pastelPurple]), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: LocalTheme.pastelPurple.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))]),
        child: Center(
          child: loading 
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(outlined ? LocalTheme.pastelPurple : Colors.white))) 
            : Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: outlined ? LocalTheme.pastelPurple : Colors.white, letterSpacing: 0.2)),
        ),
      ),
    );
  }
}