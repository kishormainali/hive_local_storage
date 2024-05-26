import 'dart:math';

import 'package:example/register_adapters.dart';
import 'package:flutter/material.dart';
import 'package:hive_local_storage/hive_local_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  late LocalStorage _localStorage;

  void _incrementCounter() async {
    await _localStorage.saveToken('access_token', 'refresh_token');
    await _localStorage.put(key: 'counter', value: Random().nextInt(100));
  }

  @override
  void initState() {
    _init();
    super.initState();
  }

  void _init() async {
    /// get the instance
    _localStorage = await LocalStorage.getInstance(
      storageDirectory: 'example',
      registerAdapters: registerAdapters,
    );

    /// get the value
    _counter = _localStorage.get<int>(key: 'counter', defaultValue: 0)!;

    final token = _localStorage.accessToken;
    print('token: $token');

    /// listen to changes
    _localStorage.watchKey<int>(key: 'counter').listen((event) {
      setState(() {
        _counter = event ?? 0;
      });
    });
    setState(() {});
  }

  void _remove() async {
    await _localStorage.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            ElevatedButton(onPressed: _remove, child: const Text('remove')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
