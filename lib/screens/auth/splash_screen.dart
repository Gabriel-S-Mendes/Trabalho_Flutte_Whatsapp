import 'package:flutter/material.dart';
import '../../config/supabase_config.dart';

class SplashScreen extends StatefulWidget {
  final Function(bool isAuthenticated) onAuthStateChanged;

  const SplashScreen({
    Key? key,
    required this.onAuthStateChanged,
  }) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 2));
    
    final isAuthenticated = SupabaseConfig.isAuthenticated;
    widget.onAuthStateChanged(isAuthenticated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo/Ícone
            Icon(
              Icons.chat_rounded,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            // Título
            const Text(
              'Chat App',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 50),
            // Loading indicator
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}