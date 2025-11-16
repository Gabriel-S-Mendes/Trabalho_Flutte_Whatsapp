import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart'; // Pacote necessário para o ChatProvider

import 'splash_page.dart'; // Sua página inicial (SplashPage)
// Não é necessário importar chat_provider.dart aqui, só na página de chat

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
    // 💡 IMPORTANTE: Envolvemos o MaterialApp com um MultiProvider.
    // Isso garante que qualquer Provider que você crie (como o ChatProvider)
    // possa ser acessado pelas suas páginas.
    return MultiProvider(
      providers: const [
        // Adicione aqui outros Providers globais se precisar (ex: AuthProvider)
      ],
      child: MaterialApp(
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        home: const SplashPage(),
      ),
    );
  }
}
