import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_readings/config/terminal_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy address is reused and only the verified key is restored',
      () async {
    SharedPreferences.setMockInitialValues({
      'terminal_backend_host': '192.168.1.100',
      'terminal_backend_port': 3000,
      'terminal_id': 'legacy-id',
      'terminal_api_key': 'aabbcc',
    });
    FlutterSecureStorage.setMockInitialValues({'terminal_api_key': 'ddeeff'});
    const storage = LocalConfigStorage();

    final legacy = await storage.load();
    expect(legacy.serverAddress, 'http://192.168.1.100:3000/api');
    expect(legacy.apiKey, isEmpty);
    expect(legacy.terminalId, isEmpty);

    const id = '14825695-6cdb-4e40-a33e-94045475eabb';
    await storage.save(legacy.copyWith(
      serverAddress: 'https://example.com/api',
      apiKey: 'ab12ef',
      terminalId: id,
    ));

    final restored = await const LocalConfigStorage().load();
    expect(restored.isConfigured, isTrue);
    expect(restored.serverAddress, 'https://example.com/api');
    expect(restored.apiKey, 'ab12ef');
    expect(restored.terminalId, id);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isNot(contains('terminal_api_key')));
  });

  test('normalizes hosted and local server addresses', () {
    const addresses = {
      ' HTTPS://EXAMPLE.COM/ ': 'https://example.com/api',
      'https://example.com:443/api/': 'https://example.com:443/api',
      'https://example.com:8443/api/api/': 'https://example.com:8443/api',
      '192.168.1.100:3000': 'http://192.168.1.100:3000/api',
      '[::1]:3000': 'http://[::1]:3000/api',
    };
    for (final entry in addresses.entries) {
      expect(TerminalConfig.normalizeServerAddress(entry.key), entry.value);
    }
  });

  test('rejects invalid schemes, hosts, ports and URL credentials', () {
    for (final value in [
      'ftp://example.com',
      'https://user@example.com',
      'https://-example.com',
      'https://999.168.1.100',
      '192.168.1.100',
      'https://example.com:0',
      'https://example.com:65536',
      'https://example.com:abc',
      'https://example.com/api?test=1',
      'http://[:::1]',
    ]) {
      expect(
        TerminalConfig.normalizeServerAddress(value),
        isNull,
        reason: value,
      );
    }
  });

  test('validates a six-character hexadecimal key', () {
    expect(TerminalConfig.validateTerminalKey(' 01AbEF '), isNull);
    expect(TerminalConfig.validateTerminalKey(''), isNotNull);
    expect(TerminalConfig.validateTerminalKey('abcdex'), isNotNull);
    expect(TerminalConfig.validateTerminalKey('abcdef0'), isNotNull);
  });
}
