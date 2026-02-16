import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../../features/bluetooth/presentation/viewmodels/bluetooth_viewmodel.dart';

@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_PeriodicTaskHandler());
}

class _PeriodicTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.sendDataToMain('tick');
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

class ForegroundService {
  static bool _initialized = false;
  static bool _callbackRegistered = false;

  static Future<void> ensureStarted(BluetoothViewModel vm) async {
    if (!_initialized) {
      FlutterForegroundTask.initCommunicationPort();
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'omi_fg_service',
          channelName: 'OMI Background Service',
          channelDescription: 'Mantiene audio y fotos en background',
          onlyAlertOnce: true,
        ),
        iosNotificationOptions: IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(10000),
          autoRunOnBoot: true,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
      _initialized = true;
    }

    if (!_callbackRegistered) {
      FlutterForegroundTask.addTaskDataCallback((Object data) {
        if (data == 'tick') {
          if (!vm.isAudioEnabled && vm.connectedDevice != null) {
            vm.startAudio();
          }
          final id = vm.photoDeviceId ?? vm.connectedDevice?.id;
          if (id != null) {
            vm.triggerPhotoFor(id);
          }
        }
      });
      _callbackRegistered = true;
    }

    await FlutterForegroundTask.startService(
      notificationTitle: 'OMI Glasses activo',
      notificationText: 'Grabando audio y tomando fotos periódicas',
      callback: _startCallback,
    );
  }

  static Future<void> stop() async {
    if (_callbackRegistered) {
      FlutterForegroundTask.removeTaskDataCallback((_) {});
      _callbackRegistered = false;
    }
    await FlutterForegroundTask.stopService();
  }
}
