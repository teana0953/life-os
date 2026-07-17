import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/config.dart';

void main() {
  test('apiBaseUrl defaults to the production workers.dev URL', () {
    expect(
      apiBaseUrl,
      'https://life-os-backend.playground-92f.workers.dev',
    );
  });
}
