import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// import 'package:twiliochat/twiliochat.dart';

void main() {
  const MethodChannel channel = MethodChannel('twiliochat');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    // expect(await Twiliochat.platformVersion, '42');
  });
}
