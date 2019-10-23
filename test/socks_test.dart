import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:socks/socks.dart';

void main() {
  test('Test Domain connection', () async {
    final sock = await RawSocket.connect(InternetAddress.loopbackIPv4, 9050);
    final s = SOCKSSocket(sock);

    await s.connect("google.com:80");

    print("done");

    await s.close(keepOpen: false);
  });

  test('Test IPv4 connection', () async {
    final sock = await RawSocket.connect(InternetAddress.loopbackIPv4, 9050);
    final s = SOCKSSocket(sock);

    final addr = await InternetAddress.lookup("google.com");
    await s.connectIp(addr.first, 80);

    print("done");

    await s.close(keepOpen: false);
  });

  test('Test IPv6 connection', () async {
    final sock = await RawSocket.connect(InternetAddress.loopbackIPv4, 9050);
    final s = SOCKSSocket(sock);

    final addr = InternetAddress("2404:6800:4008:803::200e"); //google.com
    await s.connectIp(addr, 80);

    print("done");

    await s.close(keepOpen: false);
  });
}
