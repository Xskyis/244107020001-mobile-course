import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Profil Mahasiswa')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.school, size: 72),
              SizedBox(height: 16),
              Text('Achmad Nabil Afgareza', style: TextStyle(fontSize: 24)),
              Text('244107020001', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 18),),
              Text('Teknik Informatika - 3D', style: TextStyle(fontSize: 18, fontWeight: FontWeight(500))),
              Text('Pemrograman Mobile — Minggu 1'),
            ],
          ),
        ),
      ),
    );
  }
}
