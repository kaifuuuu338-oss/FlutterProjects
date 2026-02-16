import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool elevated;

  const CustomButton({super.key, required this.label, required this.onPressed, this.elevated = true});

  @override
  Widget build(BuildContext context) {
    if (elevated) {
      return ElevatedButton(onPressed: onPressed, child: Text(label));
    } else {
      return OutlinedButton(onPressed: onPressed, child: Text(label));
    }
  }
}