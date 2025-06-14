import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: FutureBuilder<String>(
            future: Future(
              () => length("Hi".toNativeUtf8().cast<Char>()).toString(),
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              } else {
                return Text(
                  snapshot.data ?? 'Done',
                  style: TextStyle(fontSize: 24),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
