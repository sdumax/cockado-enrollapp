import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

const _deviceIdKey = 'coc_device_id';

class DeviceIdService {
  DeviceIdService(this._storage);

  final FlutterSecureStorage _storage;

  Future<String> getDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null) return existing;
    final newId = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: newId);
    return newId;
  }
}

final deviceIdServiceProvider = Provider<DeviceIdService>((ref) {
  return DeviceIdService(const FlutterSecureStorage());
});

/// Resolves and caches the device ID as an async value.
final deviceIdProvider = FutureProvider<String>((ref) async {
  return ref.watch(deviceIdServiceProvider).getDeviceId();
});
