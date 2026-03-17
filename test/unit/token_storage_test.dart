import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transvolt_fleet/features/auth/services/token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Intercept the platform channel used by flutter_secure_storage
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String?> fakeStorage = {};

  setUp(() {
    fakeStorage.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          switch (call.method) {
            case 'write':
              fakeStorage[call.arguments['key']] = call.arguments['value'];
              return null;
            case 'read':
              return fakeStorage[call.arguments['key']];
            case 'delete':
              fakeStorage.remove(call.arguments['key']);
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('TokenStorage', () {
    test('saveAccessToken stores and getAccessToken retrieves it', () async {
      await TokenStorage.saveAccessToken('test-access-token');
      final result = await TokenStorage.getAccessToken();
      expect(result, 'test-access-token');
    });

    test('saveRefreshToken stores and getRefreshToken retrieves it', () async {
      await TokenStorage.saveRefreshToken('test-refresh-token');
      final result = await TokenStorage.getRefreshToken();
      expect(result, 'test-refresh-token');
    });

    test('clearTokens removes both tokens', () async {
      await TokenStorage.saveAccessToken('access');
      await TokenStorage.saveRefreshToken('refresh');

      await TokenStorage.clearTokens();

      expect(await TokenStorage.getAccessToken(), isNull);
      expect(await TokenStorage.getRefreshToken(), isNull);
    });

    test('getAccessToken returns null when nothing stored', () async {
      final result = await TokenStorage.getAccessToken();
      expect(result, isNull);
    });

    test('saveTokens stores both access and refresh', () async {
      await TokenStorage.saveTokens('acc', 'ref');
      expect(await TokenStorage.getAccessToken(), 'acc');
      expect(await TokenStorage.getRefreshToken(), 'ref');
    });
  });
}
