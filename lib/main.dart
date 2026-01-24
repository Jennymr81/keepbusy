import 'package:flutter/material.dart';

import 'package:keepbusy/repositories/local/profiles_repository_isar.dart';
import 'pages/home_page.dart';
import 'theme/app_theme.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // This opens Isar via db.dart (through ProfileService)
await ProfilesRepositoryIsar.init();

  runApp(const KeepBusyApp());
}

// Global ScaffoldMessenger for any helper that wants to show a SnackBar
final messengerKey = GlobalKey<ScaffoldMessengerState>();

void showSnack(String msg) {
  messengerKey.currentState?.showSnackBar(
    SnackBar(content: Text(msg)),
  );
}


// Root app widget – theme + home page
class KeepBusyApp extends StatelessWidget {
  const KeepBusyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KeepBusy',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
     theme: buildAppTheme(),
      home: const KeepBusyHomePage(),
    );
  }
}
