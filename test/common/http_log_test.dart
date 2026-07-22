import 'package:fl_clash/common/http.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('network route log omits path, query, and credentials', () {
    final message = formatNetworkRouteLog(
      Uri.parse(
        'https://user:password@example.com/config/main/secret-token?auth=hidden',
      ),
      proxy: false,
    );

    expect(message, 'network-route host=example.com scheme=https proxy=false');
    expect(message, isNot(contains('secret-token')));
    expect(message, isNot(contains('password')));
    expect(message, isNot(contains('auth')));
  });
}
