import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../../../bluetooth/presentation/viewmodels/bluetooth_viewmodel.dart';
import '../../domain/entities/app_settings.dart';
import '../bloc/settings_bloc.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BluetoothViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final s = state.settings;
          final keyController = TextEditingController(
            text: s.geminiApiKey ?? '',
          );
          final ids = <String>{};
          final devices = vm.connectedDevices
              .where((d) => ids.add(d.id))
              .toList();
          final photoIntervalController = TextEditingController(
            text: s.photoIntervalSeconds.toString(),
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gemini API Key'),
                const SizedBox(height: 8),
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Introduce tu API Key',
                  ),
                  onChanged: (v) {
                    context.read<SettingsBloc>().add(SetGeminiKey(v));
                  },
                ),
                const SizedBox(height: 16),
                const Text('Fuente de Audio'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: devices.any((d) => d.id == s.audioDeviceId)
                      ? s.audioDeviceId
                      : null,
                  items: devices
                      .map(
                        (d) =>
                            DropdownMenuItem(value: d.id, child: Text(d.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    context.read<SettingsBloc>().add(SetAudioDevice(v));
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Fuente de Fotos'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: devices.any((d) => d.id == s.photoDeviceId)
                      ? s.photoDeviceId
                      : null,
                  items: devices
                      .map(
                        (d) =>
                            DropdownMenuItem(value: d.id, child: Text(d.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    context.read<SettingsBloc>().add(SetPhotoDevice(v));
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Intervalo de Foto (segundos)'),
                const SizedBox(height: 8),
                TextField(
                  controller: photoIntervalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v) ?? 60;
                    context.read<SettingsBloc>().add(SetPhotoInterval(n));
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    context.read<SettingsBloc>().add(PersistSettings());
                    final s2 = context.read<SettingsBloc>().state.settings;
                    if (s2.audioDeviceId != null) {
                      vm.setAudioSource(s2.audioDeviceId!);
                    }
                    if (s2.photoDeviceId != null) {
                      vm.setPhotoSource(
                        s2.photoDeviceId!,
                        interval: Duration(seconds: s2.photoIntervalSeconds),
                      );
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Configuración guardada')),
                    );
                  },
                  child: const Text('Guardar y Aplicar'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    await vm.requestBackgroundPermissions();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Permisos de background solicitados'),
                      ),
                    );
                  },
                  child: const Text('Solicitar permisos de background'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
