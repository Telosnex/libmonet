import 'dart:io';

import 'package:example/color_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:libmonet/extract/extract.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var _color = const Color(0xff334157);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton.icon(
                onPressed: _uploadImagePressed,
                icon: const Icon(Icons.photo),
                label: const Text('Upload Image')),
            ColorPicker(
              color: _color,
              onColorChanged: (newColor) {
                setState(() {
                  _color = newColor;
                });
              },
            )
          ],
        ),
      ),
    );
  }

  void _uploadImagePressed() async {
    final imageProvider = await _pickImage();
    if (imageProvider == null) {
      return;
    }
    final sw = Stopwatch()..start();
    final quantizerResult = await Extract.quantize(imageProvider, 64);
    print('Quantization took ${sw.elapsedMilliseconds}ms');
    final entriesSortedByCountDescending = quantizerResult.argbToCount.entries
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topColor = entriesSortedByCountDescending.first.key;
    setState(() {
      _color = Color(topColor);
    });
  }

  Future<ImageProvider<Object>?> _pickImage() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(source: ImageSource.gallery);
    if (imageFile == null) {
      return null;
    }
    if (kIsWeb) {
      return NetworkImage(imageFile.path);
    } else {
      return FileImage(File(imageFile.path));
    }
  }
}
