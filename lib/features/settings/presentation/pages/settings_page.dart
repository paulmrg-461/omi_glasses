import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../bluetooth/presentation/viewmodels/bluetooth_viewmodel.dart';
import '../bloc/settings_bloc.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _keyController;
  late TextEditingController _localAudioController;
  late TextEditingController _localVisionController;
  late TextEditingController _photoIntervalController;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsBloc>().state.settings;
    _keyController = TextEditingController(text: s.geminiApiKey ?? '');
    _localAudioController = TextEditingController(text: s.localAudioUrl ?? '');
    _localVisionController = TextEditingController(
      text: s.localVisionUrl ?? '',
    );
    _photoIntervalController = TextEditingController(
      text: s.photoIntervalSeconds.toString(),
    );
  }

  @override
  void dispose() {
    _keyController.dispose();
    _localAudioController.dispose();
    _localVisionController.dispose();
    _photoIntervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BluetoothViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: BlocConsumer<SettingsBloc, SettingsState>(
        listenWhen: (previous, current) =>
            previous.settings != current.settings,
        listener: (context, state) {
          final s = state.settings;
          // Sync controllers with state if they differ (e.g. initial load or external update)
          if ((s.geminiApiKey ?? '') != _keyController.text) {
            _keyController.text = s.geminiApiKey ?? '';
          }
          if ((s.localAudioUrl ?? '') != _localAudioController.text) {
            _localAudioController.text = s.localAudioUrl ?? '';
          }
          if ((s.localVisionUrl ?? '') != _localVisionController.text) {
            _localVisionController.text = s.localVisionUrl ?? '';
          }
          final intervalStr = s.photoIntervalSeconds.toString();
          if (intervalStr != _photoIntervalController.text) {
            // Note: This might snap back empty string to "60" while typing,
            // but preserving focus is the priority.
            _photoIntervalController.text = intervalStr;
          }
        },
        builder: (context, state) {
          final s = state.settings;
          final ids = <String>{};
          final devices = vm.connectedDevices
              .where((d) => ids.add(d.id))
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gemini API Key'),
                const SizedBox(height: 8),
                TextField(
                  controller: _keyController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Introduce tu API Key',
                  ),
                  onChanged: (v) {
                    context.read<SettingsBloc>().add(SetGeminiKey(v));
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Usar modelos locales'),
                  subtitle: const Text(
                    'Si está desactivado, se usará Gemini en la nube',
                  ),
                  value: s.useLocalModels,
                  onChanged: (v) {
                    context.read<SettingsBloc>().add(SetUseLocalModels(v));
                  },
                ),
                if (s.useLocalModels) ...[
                  const SizedBox(height: 8),
                  const Text('URL Local Audio (WS)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _localAudioController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'ws://192.168.1.10:8000',
                      labelText: 'URL Local Audio (WS)',
                    ),
                    onChanged: (v) {
                      context.read<SettingsBloc>().add(SetLocalAudioUrl(v));
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('URL Local Visión (HTTP)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _localVisionController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'http://192.168.1.10:8000',
                      labelText: 'URL Local Visión (HTTP)',
                    ),
                    onChanged: (v) {
                      context.read<SettingsBloc>().add(SetLocalVisionUrl(v));
                    },
                  ),
                  const SizedBox(height: 16),
                ],
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
                  controller: _photoIntervalController,
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
