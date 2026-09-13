import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/app_router.dart';

void main() => runApp(const ProviderScope(child: MyApp()));

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Week 3 - ToDo Riverpod',
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF0F172A),
          useMaterial3: true,
        ),
      );
}
