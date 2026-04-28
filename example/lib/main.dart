import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:monet_studio/home.dart';

const _initialColor = Color(0xff335147);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Monet Studio',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: _initialColor),
          useMaterial3: true,
        ),
        home: const Home(initialColor: _initialColor),
      ),
    );
  }
}
