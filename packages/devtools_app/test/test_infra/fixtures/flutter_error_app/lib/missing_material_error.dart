// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:flutter/material.dart';

class MissingMaterialError extends StatelessWidget {
  const MissingMaterialError({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Missing Material',
      home: ExampleWidget(),
      // The line below can resolve the error.
      // home: Scaffold(body: new ExampleWidget()),
    );
  }
}

/// Opens an [AlertDialog] showing what the user typed.
class ExampleWidget extends StatefulWidget {
  const ExampleWidget({super.key});

  @override
  State<ExampleWidget> createState() => _ExampleWidgetState();
}

/// State for [ExampleWidget] widgets.
class _ExampleWidgetState extends State<ExampleWidget> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: 'Type something',
          ),
        ),
        ElevatedButton(
          onPressed: () {
            unawaited(
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('What you typed'),
                  content: Text(_controller.text),
                ),
              ),
            );
          },
          child: const Text('DONE'),
        ),
      ],
    );
  }
}
