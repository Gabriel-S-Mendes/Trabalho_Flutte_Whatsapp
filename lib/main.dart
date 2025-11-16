import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'splash_page.dart'; // Sua página inicial (SplashPage)

// 🔑 Configurações do Supabase
const String supabaseUrl = 'https://ftnxnhqvkthlsodmgcof.supabase.co';
const String supabaseKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ0bnhuaHF2a3RobHNvZG1nY29mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMyNTQzNjAsImV4cCI6MjA3ODgzMDM2MH0.ycb93-y4po6bw8zynRIaBjeGm70MCPzsgQ56Ev_BEWA';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(const MyApp());
}

// Helper global para acessar o cliente Supabase
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whatsapp 2 - Clash Royale',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.green,
          accentColor: Colors.tealAccent[400],
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E2125),
        ),
        scaffoldBackgroundColor: const Color(0xFF151515),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const SplashPage(),
    );
  }
}
