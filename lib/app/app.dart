import 'package:flutter/material.dart';
import 'theme.dart';
import 'auth_wrapper.dart';

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DT Pizza Delivery',
      theme: appTheme,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}
