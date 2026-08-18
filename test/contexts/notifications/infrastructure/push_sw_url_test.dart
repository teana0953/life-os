import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/infrastructure/push_sw_url.dart';

void main() {
  test('keeps the script path relative so the /push/ scope stays legal', () {
    // An absolute or parent path would make `register(..., {scope: '/push/'})`
    // fail the scope check; the file is served at the origin root.
    expect(pushSwScriptUrl('https://api.test'), startsWith('push_sw.js?'));
  });

  test('round-trips the base URL through the query', () {
    final value = Uri.parse(
      pushSwScriptUrl('https://api.test'),
    ).queryParameters.values.single;
    expect(value, 'https://api.test');
  });

  test('encodes a base URL that itself contains a query', () {
    // `&`/`=` inside the value would otherwise be read as further parameters,
    // truncating the endpoint the worker builds.
    const base = 'https://api.test/v1?a=1&b=2';
    final url = pushSwScriptUrl(base);
    expect(url, isNot(contains('&b=2')));
    expect(Uri.parse(url).queryParameters.values.single, base);
  });

  test('strips trailing slashes, since the worker concatenates verbatim', () {
    // `https://api.test//api/push/ack` is a different path; normalizing on one
    // side only is what keeps the two sides from both doing it, or neither.
    expect(
      Uri.parse(pushSwScriptUrl('https://api.test/')).queryParameters['api'],
      'https://api.test',
    );
    expect(
      Uri.parse(pushSwScriptUrl('https://api.test///')).queryParameters['api'],
      'https://api.test',
    );
  });
}
