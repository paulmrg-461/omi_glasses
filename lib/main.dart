import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/di/injection_container.dart' as di;
import 'features/bluetooth/presentation/pages/bluetooth_scan_page.dart';
import 'features/bluetooth/presentation/viewmodels/bluetooth_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      ],
      child: MaterialApp(
        title: 'OMI Glasses',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const BluetoothScanPage(),
      ),
    );
  }
}
