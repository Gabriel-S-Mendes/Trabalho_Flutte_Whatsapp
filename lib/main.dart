import 'package:flutter/material.dart';
import 'ui/widgets/custom_input.dart';

void main() {
  runApp( MainApp());
}

class MainApp extends StatelessWidget {
   MainApp({super.key});

TextEditingController emailControler = TextEditingController();
TextEditingController passworldControler = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding:  EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                 SizedBox(width: double.infinity,child: Text('Login'),),
                 CustomInput(labelText: 'Digite seu e-mail',hint: 'kleber', controller:emailControler),
                 SizedBox(height: 16),
                 CustomInput(labelText: 'Digite sua senha',hint: 'kleber',controller:passworldControler),
                ElevatedButton(onPressed:() {}, child: const Text("login")),
              ],
            
            ),
          ),
        ),
      ),
    );
  }
}
