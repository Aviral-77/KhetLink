import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/auth_service.dart';

// A very small in-memory Fake for SecureStorageInterface for testing.
class InMemoryStorage implements SecureStorageInterface {
  final Map<String, String> _map = {};
  @override
  Future<void> delete({required String key}) async => _map.remove(key);
  @override
  Future<void> deleteAll() async => _map.clear();
  @override
  Future<String?> read({required String key}) async => _map[key];
  @override
  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      _map.remove(key);
      return;
    }
    _map[key] = value;
  }
}

void main() {
  test('register then login stores token and username', () async {
    final fake = InMemoryStorage();
    final svc = AuthService(storage: fake);

    expect(await svc.isAuthenticated(), isFalse);

    await svc.register('tester', 'password');

    final token = await svc.token();
    final uname = await svc.username();

    expect(token, isNotNull);
    expect(uname, 'tester');
    expect(await svc.isAuthenticated(), isTrue);

    await svc.logout();
    expect(await svc.token(), isNull);
    expect(await svc.isAuthenticated(), isFalse);
  });
}
