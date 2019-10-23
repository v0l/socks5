import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:socks/socks.dart';

void main() {
  test('adds one to input values', () async {
    final s = SOCKSSocket(InternetAddress.loopbackIPv4, port: 9050);
    await s.connect("5qwyyntt2fcmi66x.onion:9999");
    await s.waitForExit;
  });
}
