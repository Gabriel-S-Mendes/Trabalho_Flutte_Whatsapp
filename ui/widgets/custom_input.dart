import 'package:flutter/material.dart';

class CustomInput extends StatelessWidget {
  final String labelText;
  final String hint;
  final TextEditingController controller; // 
  const CustomInput({
    super.key,
    required this.labelText,
    required this.hint,
    required this.controller, required bool obscureText, // 
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller, //
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hint,
        border: OutlineInputBorder(),
      ),
    );
  }
}
