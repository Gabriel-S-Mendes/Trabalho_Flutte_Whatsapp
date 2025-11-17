import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:provider/provider.dart'; // Removido, pois não estamos usando Providers globais.

import 'splash_page.dart'; // Sua página inicial (SplashPage)

// 🔑 Configurações do Supabase (Usamos apenas a constante aqui)
const String supabaseUrl = 'https://ftnxnhqvkthlsodmgcof.supabase.co';
const String supabaseKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ0bnhuaHF2a3RobHNvZG1nY29mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMyNTQzNjAsImV4cCI6MjA3ODgzMDM2MH0.ycb93-y4po6bw8zynRIaBjeGm70MCPzsgQ56Ev_BEWA';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Supabase usando as constantes
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
    // 💡 CORREÇÃO: Removemos o MultiProvider, pois a lista estava vazia e causava o erro.
    return MaterialApp(
      title: 'Whatsapp 2 - Clash Royale',
      theme: ThemeData.dark().copyWith(
        // Estilo de cores atualizado
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.green,
          accentColor: Colors.tealAccent[400],
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E2125), // Cor de fundo para appbar
        ),
        scaffoldBackgroundColor: const Color(0xFF151515), // Fundo escuro
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      home: const SplashPage(),
    );
  }
}
