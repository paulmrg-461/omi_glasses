import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/bluetooth_viewmodel.dart';

class WifiConfigDialog extends StatefulWidget {
  final BluetoothViewModel viewModel;

  const WifiConfigDialog({super.key, required this.viewModel});

  @override
  State<WifiConfigDialog> createState() => _WifiConfigDialogState();
}

class _WifiConfigDialogState extends State<WifiConfigDialog> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch for changes in viewModel to update loading state/error
    final viewModel = context.watch<BluetoothViewModel>();

    return AlertDialog(
      title: const Text("Configure Wi-Fi"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Enter your Wi-Fi credentials to enable camera streaming.",
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ssidController,
                decoration: const InputDecoration(
                  labelText: "SSID (Network Name)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.wifi),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'SSID is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) => value == null || value.length < 8
                    ? 'Password must be at least 8 chars'
                    : null,
              ),
              if (viewModel.isSettingUpWifi)
                const Padding(
                  padding: EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text("Sending credentials..."),
                    ],
                  ),
                ),
              if (viewModel.errorMessage != null &&
                  viewModel.errorMessage!.contains("Wi-Fi"))
                Padding(
                  padding: EdgeInsets.only(top: 16.0),
                  child: Text(
                    viewModel.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: viewModel.isSettingUpWifi
              ? null
              : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: viewModel.isSettingUpWifi
              ? null
              : () {
                  if (_formKey.currentState!.validate()) {
                    // Use the passed viewModel (widget.viewModel) or the watched one.
                    // Ideally use the method on the watched one to ensure consistency?
                    // But methods are on the object.
                    widget.viewModel.setupWifi(
                      _ssidController.text,
                      _passwordController.text,
                    );

                    // We don't pop immediately so the user can see the loading state.
                    // But if it succeeds, we should probably pop?
                    // The ViewModel will update state.
                    // Let's rely on the user closing or the UI updating.
                    // Or we can close and show a SnackBar.
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Credentials sent. Waiting for connection...",
                        ),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }
                },
          child: const Text("Connect"),
        ),
      ],
    );
  }
}
