import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../bluetooth/presentation/pages/bluetooth_scan_page.dart';
import '../../../memory/domain/entities/memory_entry.dart';
import '../../../memory/domain/repositories/memory_repository.dart';
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

  @override
  void initState() {
    super.initState();
    _loadMemories();
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
          NavigationDestination(icon: Icon(Icons.settings), label: 'Ajustes'),
        ],
        onDestinationSelected: (i) {
          setState(() {
            _index = i;
          });
        },
      ),
    );
  }
}
