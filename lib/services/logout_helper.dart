// lib/services/logout_helper.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> logout(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
}
