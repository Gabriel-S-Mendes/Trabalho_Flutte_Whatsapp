import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'splash_page.dart'; // Sua página inicial

// 🔑 Configurações do Supabase
const supabaseUrl = 'https://ftnxnhqvkthlsodmgcof.supabase.co';
const supabaseKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ0bnhuaHF2a3RobHNvZG1nY29mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMyNTQzNjAsImV4cCI6MjA3ODgzMDM2MH0.ycb93-y4po6bw8zynRIaBjeGm70MCPzsgQ56Ev_BEWA';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ftnxnhqvkthlsodmgcof.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ0bnhuaHF2a3RobHNvZG1nY29mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMyNTQzNjAsImV4cCI6MjA3ODgzMDM2MH0.ycb93-y4po6bw8zynRIaBjeGm70MCPzsgQ56Ev_BEWA',
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
        primaryColor: Colors.green,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
        ),
      ),
      home: const SplashPage(),
    );
  }
}
