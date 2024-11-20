import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import 'bottom_navbar.dart';
import 'managers/sql_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  await VectorStore.database;
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({required this.cameras, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ONNX Garbage Classifier',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(cameras: cameras),
    );
  }
}