import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // <-- Este import será usado agora
import 'package:flutter_dotenv/flutter_dotenv.dart';   // <-- Novo import
import 'splash_page.dart'; // (Ou sua página inicial)

Future<void> main() async {
  // Garante que o Flutter está inicializado
  WidgetsFlutterBinding.ensureInitialized();

  // Carrega as variáveis de ambiente do arquivo .env
  await dotenv.load(fileName: ".env");

  // Inicializa o Supabase com as chaves carregadas
  await Supabase.initialize(
    // Acessa as variáveis carregadas do .env
    url: dotenv.env['SUPABASE_URL']!, 
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(MyApp());
}

// Helper global para acessar o cliente Supabase
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Login Demo',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.green,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
        ),
      ),
      home: SplashPage(), // Começamos pela Splash Page
    );
  }
}