import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/di/injection_container.dart' as di;
import 'features/bluetooth/presentation/viewmodels/bluetooth_viewmodel.dart';
import 'features/chat/presentation/viewmodels/chat_viewmodel.dart';
import 'features/app/presentation/pages/app_tabs_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: .env file not found or failed to load: $e");
  }
  await di.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => di.sl<BluetoothViewModel>()),
        ChangeNotifierProvider(create: (_) => di.sl<ChatViewModel>()),
      ],
      child: MaterialApp(
        title: 'OMI Glasses',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const AppTabsPage(),
      ),
    );
  }
}
