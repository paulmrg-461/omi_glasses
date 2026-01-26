import 'package:equatable/equatable.dart';

class BluetoothDeviceEntity extends Equatable {
  final String id;
  final String name;
  final int rssi;
  final List<String> serviceUuids;

  const BluetoothDeviceEntity({
    required this.id,
    required this.name,
    required this.rssi,
    this.serviceUuids = const [],
  });

  @override
  List<Object?> get props => [id, name, rssi, serviceUuids];
}
