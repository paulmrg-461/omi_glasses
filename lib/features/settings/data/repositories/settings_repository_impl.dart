import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_data_source.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDataSource local;
  SettingsRepositoryImpl({required this.local});
  @override
  Future<AppSettings> load() => local.load();
  @override
  Future<void> save(AppSettings settings) => local.save(settings);
}
