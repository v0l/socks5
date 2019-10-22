import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:socks/socks.dart';

void main() {
  test('adds one to input values', () async {
    final s = SOCKSSocket(InternetAddress.loopbackIPv4, port: 9050);
    await s.connect("cup3sndn4z2bnc2z.onion:9999");
    await s.waitForExit;
  });
}
