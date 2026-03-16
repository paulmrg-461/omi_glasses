import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../viewmodels/bluetooth_viewmodel.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({super.key});

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  final TextEditingController _cmdController = TextEditingController();

  @override
  void dispose() {
    _cmdController.dispose();
    super.dispose();
  }

  Widget _buildCommandDialog(BuildContext context) {
    final vm = context.read<BluetoothViewModel>();
    return AlertDialog(
      title: const Text("Enviar Comando RAW"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _cmdController,
              decoration: const InputDecoration(
                labelText: "Hex (ej: AB 00 04...)",
                hintText: "Separado por espacios",
              ),
            ),
            const SizedBox(height: 16),
            const Text("Comandos rápidos:"),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text("Full Y25 Init (Recommended)"),
                  backgroundColor: Colors.greenAccent,
                  onPressed: () {
                    vm.triggerY25Init();
                    Navigator.pop(context);
                  },
                ),
                ActionChip(
                  label: const Text("Init Lefun (AB 04)"),
                  onPressed: () {
                    _cmdController.text = "AB 00 04 00 00 00 80";
                  },
                ),
                ActionChip(
                  label: const Text("Init Generic"),
                  onPressed: () {
                    _cmdController.text = "01 00";
                  },
                ),
                ActionChip(
                  label: const Text("Start HR (AB 05)"),
                  onPressed: () {
                    _cmdController.text = "AB 00 05 00 00 00 80";
                  },
                ),
                ActionChip(
                  label: const Text("Start HR (AB 03)"),
                  onPressed: () {
                    _cmdController.text = "AB 00 03 00 00 00 80";
                  },
                ),
                ActionChip(
                  label: const Text("Start HR (15 01)"),
                  onPressed: () {
                    // Standard BLE HR Control Point "Start"
                    _cmdController.text = "15 01 01";
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: () {
            vm.sendRawDebugCommand(_cmdController.text);
            Navigator.pop(context);
          },
          child: const Text("Enviar"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salud y Bienestar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.terminal),
            tooltip: "Consola Hex",
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => _buildCommandDialog(ctx),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Trigger a manual refresh if needed
              final vm = context.read<BluetoothViewModel>();
              if (vm.connectedDevice != null) {
                vm.retryServiceDiscovery();
              }
            },
          ),
        ],
      ),
      body: Consumer<BluetoothViewModel>(
        builder: (context, vm, child) {
          if (vm.connectedDevice == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.bluetooth_disabled,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay dispositivo conectado',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate back to scan page logic or just show message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Ve a la pestaña Inicio para conectar un dispositivo',
                          ),
                        ),
                      );
                    },
                    child: const Text('Conectar Dispositivo'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDeviceHeader(context, vm),
                if (vm.statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      vm.statusMessage!,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                _buildHealthGrid(context, vm),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "Debug / Logs (${vm.connectedDevice?.id ?? ''})",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: vm.simulateHealthData,
                      child: const Text("Simular"),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: "Copiar Logs",
                      onPressed: () async {
                        final logs = vm.debugLogs.isNotEmpty
                            ? vm.debugLogs
                            : vm.connectedDeviceServices;
                        if (logs.isNotEmpty) {
                          final text = logs.join('\n');
                          await Clipboard.setData(ClipboardData(text: text));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Logs copiados al portapapeles'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: "Reiniciar Monitor",
                      onPressed: () {
                        if (vm.connectedDevice != null) {
                          vm.startDebugListener(vm.connectedDevice!.id);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDebugLogs(vm),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeviceHeader(BuildContext context, BluetoothViewModel vm) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.watch, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vm.connectedDevice?.name ?? 'Desconocido',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  vm.connectedDevice?.id ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const Spacer(),
            if (vm.batteryLevel != null)
              Row(
                children: [
                  Icon(
                    vm.batteryLevel! > 20
                        ? Icons.battery_full
                        : Icons.battery_alert,
                    color: vm.batteryLevel! > 20 ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text("${vm.batteryLevel}%"),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthGrid(BuildContext context, BluetoothViewModel vm) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _buildMetricCard(
          context,
          icon: Icons.favorite,
          color: Colors.red,
          title: "Ritmo Cardíaco",
          value: "${vm.heartRate ?? '--'}",
          unit: "BPM",
        ),
        _buildMetricCard(
          context,
          icon: Icons.directions_walk,
          color: Colors.orange,
          title: "Pasos",
          value: "${vm.steps}",
          unit: "pasos",
        ),
        _buildMetricCard(
          context,
          icon: Icons.local_fire_department,
          color: Colors.deepOrange,
          title: "Calorías",
          value: "${vm.calories}",
          unit: "kcal",
        ),
        _buildMetricCard(
          context,
          icon: Icons.bedtime,
          color: Colors.indigo,
          title: "Sueño",
          value: vm.sleepDuration,
          unit: "duración",
        ),
        _buildMetricCard(
          context,
          icon: Icons.water_drop,
          color: Colors.blue,
          title: "Oxígeno (SpO2)",
          value: "${vm.bloodOxygen}",
          unit: "%",
        ),
        _buildMetricCard(
          context,
          icon: Icons.thermostat,
          color: Colors.amber,
          title: "Temperatura",
          value: "${vm.temperature}",
          unit: "°C",
        ),
        _buildMetricCard(
          context,
          icon: Icons.psychology,
          color: Colors.purple,
          title: "Estrés",
          value: "${vm.stress}",
          unit: "/ 100",
        ),
        _buildMetricCard(
          context,
          icon: Icons.map,
          color: Colors.green,
          title: "Distancia",
          value: "${vm.distanceKm}",
          unit: "km",
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String unit,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              // Optional trend icon or indicator
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                "$unit • $title",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebugLogs(BluetoothViewModel vm) {
    final logs = vm.debugLogs.isNotEmpty
        ? vm.debugLogs
        : vm.connectedDeviceServices;

    if (logs.isEmpty) {
      return const Text("No hay logs disponibles.");
    }
    return Container(
      height: 300, // Aumentar altura para ver más
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        itemCount: logs.length,
        // Auto-scroll al final (terminal style)
        reverse: true,
        itemBuilder: (context, index) {
          // Mostrar lo más nuevo abajo
          final logIndex = logs.length - 1 - index;
          return Text(
            logs[logIndex],
            style: const TextStyle(
              color: Colors.greenAccent,
              fontFamily: 'Courier',
              fontSize: 10,
            ),
          );
        },
      ),
    );
  }
}
