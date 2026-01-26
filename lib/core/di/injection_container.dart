import 'package:get_it/get_it.dart';
import '../../features/bluetooth/data/datasources/bluetooth_remote_data_source.dart';
import '../../features/bluetooth/data/repositories/bluetooth_repository_impl.dart';
import '../../features/bluetooth/domain/repositories/bluetooth_repository.dart';
import '../../features/bluetooth/presentation/viewmodels/bluetooth_viewmodel.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Features - Bluetooth
  // ViewModel
  sl.registerFactory(() => BluetoothViewModel(repository: sl()));

  // Repository
  sl.registerLazySingleton<BluetoothRepository>(
    () => BluetoothRepositoryImpl(dataSource: sl()),
  );

  // Data Source
  sl.registerLazySingleton<BluetoothRemoteDataSource>(
    () => BluetoothRemoteDataSourceImpl(),
  );
}
