import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kiobro',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.blueAccent,
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: Colors.blueAccent.withOpacity(0.3),
          selectionHandleColor: Colors.blueAccent,
          cursorColor: Colors.blueAccent,
        ),
      ),
      home: const HomePage(),
    );
  }
}
