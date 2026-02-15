import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../bluetooth/presentation/pages/bluetooth_scan_page.dart';
import '../../../memory/domain/entities/memory_entry.dart';
import '../../../memory/domain/repositories/memory_repository.dart';
import '../../../photo/domain/entities/photo_entry.dart';
import '../../../photo/domain/repositories/photo_repository.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/pages/settings_page.dart';

class AppTabsPage extends StatefulWidget {
  const AppTabsPage({super.key});
  @override
  State<AppTabsPage> createState() => _AppTabsPageState();
}

class _AppTabsPageState extends State<AppTabsPage> {
  int _index = 0;
  List<MemoryEntry> _memories = [];
  bool _loadingMem = false;
  List<PhotoEntry> _photos = [];
  bool _loadingPhotos = false;

  @override
  void initState() {
    super.initState();
    _loadMemories();
    _loadPhotos();
  }

  Future<void> _loadMemories() async {
    setState(() {
      _loadingMem = true;
    });
    final repo = di.sl<MemoryRepository>();
    final list = await repo.list();
    setState(() {
      _memories = list;
      _loadingMem = false;
    });
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _loadingPhotos = true;
    });
    final repo = di.sl<PhotoRepository>();
    final list = await repo.list();
    setState(() {
      _photos = list;
      _loadingPhotos = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: [
            const BluetoothScanPage(showAppBar: false),
            RefreshIndicator(
              onRefresh: _loadMemories,
              child: _loadingMem
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _memories.length,
                      itemBuilder: (_, i) {
                        final m = _memories[i];
                        return Card(
                          child: ListTile(
                            title: Text(
                              m.summary.isNotEmpty ? m.summary : 'Sin resumen',
                            ),
                            subtitle: Text(
                              m.transcript.isNotEmpty
                                  ? m.transcript
                                  : 'Sin transcripción',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              '${m.timestamp.hour.toString().padLeft(2, '0')}:${m.timestamp.minute.toString().padLeft(2, '0')}',
                            ),
                          ),
                        );
                      },
                    ),
            ),
            RefreshIndicator(
              onRefresh: _loadPhotos,
              child: _loadingPhotos
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _photos.length,
                      itemBuilder: (_, i) {
                        final p = _photos[i];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${p.timestamp.year}-${p.timestamp.month.toString().padLeft(2, '0')}-${p.timestamp.day.toString().padLeft(2, '0')} '
                                  '${p.timestamp.hour.toString().padLeft(2, '0')}:${p.timestamp.minute.toString().padLeft(2, '0')}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                Image.memory(
                                  base64Decode(p.imageBase64),
                                  height: 180,
                                  fit: BoxFit.cover,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  p.description.isNotEmpty
                                      ? p.description
                                      : 'Sin descripción',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            BlocProvider(
              create: (_) => di.sl<SettingsBloc>()..add(LoadSettings()),
              child: const SettingsPage(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
          NavigationDestination(
            icon: Icon(Icons.photo_library),
            label: 'Fotos',
          ),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Ajustes'),
        ],
        onDestinationSelected: (i) {
          setState(() {
            _index = i;
          });
          if (i == 1) {
            _loadMemories();
          } else if (i == 2) {
            _loadPhotos();
          }
        },
      ),
    );
  }
}
