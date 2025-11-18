import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'splash_page.dart'; // Sua página inicial (SplashPage)

// -------------------------------------------------------------------------
// 🎨 PALETA DE CORES COESA
// -------------------------------------------------------------------------

// Cores definidas na nossa estratégia:
const Color primaryTeal = Color(0xFF009688); // Cor de Destaque / Ação
const Color darkBackground = Color(0xFF0A0A0A); // Fundo Profundo
const Color darkSurface =
    Color(0xFF1E1E1E); // Superfície (Cards, AppBars, Inputs)
const Color textPrimary = Color(0xFFFAFAFA); // Texto Principal
const Color textSecondary =
    Color(0xFFA0A0A0); // Texto Secundário (Hints, Status)
const Color errorColor = Color(0xFFFF5252); // Erro / Logout

ThemeData appDarkTheme() {
  return ThemeData(
    // 1. Cores Base
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    cardColor: darkSurface,
    canvasColor: darkBackground, // Fundo de Drawer/Dialogs

    // 2. Cores de Esquema (Melhor prática moderna)
    colorScheme: const ColorScheme.dark(
      primary: primaryTeal, // Cor principal de destaque (Teal)
      onPrimary: Colors.white, // Conteúdo sobre o Teal
      secondary: primaryTeal, // Cor secundária de destaque
      surface: darkSurface, // Cor de Cards, Inputs, AppBars
      background: darkBackground,
      error: errorColor,
      onBackground: textPrimary, // Cor do texto principal no background
    ),

    // 3. App Bar
    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: textPrimary,
      elevation: 1, // Leve sombra para profundidade
    ),

    // 4. Input e Form Fields (Aplicado a Login/Cadastro)
    inputDecorationTheme: InputDecorationTheme(
      fillColor: darkSurface,
      filled: true,
      hintStyle: const TextStyle(color: textSecondary), // Cinza para Hints
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), // Bordas arredondadas
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        // Borda Teal no foco
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryTeal, width: 2),
      ),
    ),

    // 5. Botões Elevados (Login/Cadastrar)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),

    // 6. Textos (Garantindo que o Texto Principal e Secundário sejam consistentes)
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textPrimary),
      titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
      titleMedium:
          TextStyle(color: textSecondary), // Usado para status/descrições
    ),
  );
}

// -------------------------------------------------------------------------
// 🔑 CONFIGURAÇÃO SUPABASE
// -------------------------------------------------------------------------

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
      debugShowCheckedModeBanner: false,
      // Aplicamos a função de tema customizada aqui:
      theme: appDarkTheme(),
      home: const SplashPage(),
    );
  }
}
