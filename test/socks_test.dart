import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:socks5/socks5.dart';

Future<void> httpGet(RawSocket rs, SOCKSSocket s, String host) async {
  final sub = s.subscription;
  s.subscription.onData((data) {
    print(data);
    if (data == RawSocketEvent.read) {
      final data = rs.read(rs.available());
      print(Utf8Decoder().convert(data as List<int>, 0, 255));
    } else if (data == RawSocketEvent.closed) {
      sub.cancel();
    }
  });

  rs.write(utf8.encode(
      "GET / HTTP/1.1\r\nHost: $host\r\nUser-Agent: socks5/1.0\r\nAccept: */*\r\n\r\n"));
  await sub.asFuture();
}

Future<void> httpsGet(RawSecureSocket rs, SOCKSSocket s, String host) async {
  final sub = rs.listen((data) async {
    print(data);
    if (data == RawSocketEvent.read) {
      final data = rs.read(rs.available());
      print(Utf8Decoder().convert(data as List<int>, 0, 255));
    } else if (data == RawSocketEvent.closed) {
      await rs.close();
    }
  });

  rs.write(utf8.encode(
      "GET / HTTP/1.1\r\nHost: $host\r\nUser-Agent: socks5/1.0\r\nAccept: */*\r\n\r\n"));
  await sub.asFuture();
  sub.cancel();
}

void main() {
  test('Test Domain connection', () async {
    final sock = await RawSocket.connect(InternetAddress.loopbackIPv4, 9050);
    final s = SOCKSSocket(sock);

    await s.connect("google.com:80");

    await httpGet(sock, s, "google.com");

    await s.close(keepOpen: false);
  });

  test('Test IPv4 connection', () async {
    final sock = await RawSocket.connect(InternetAddress.loopbackIPv4, 9050);
    final s = SOCKSSocket(sock);

    final addr = await InternetAddress.lookup("google.com");
    await s.connectIp(addr.first, 80);

    await httpGet(sock, s, "google.com");

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

  test('Test username:password connection', () async {
    final sock = await RawSocket.connect(InternetAddress.loopbackIPv4, 1080);
    final s = SOCKSSocket(
      sock,
      username: "test",
      password: "test",
      auth: [AuthMethods.NoAuth, AuthMethods.UsernamePassword],
    );

    await s.connect("google.com:80");

    print("done");

    await s.close(keepOpen: false);
  });

/*
  test('SSL socket (TOR)', () async {
    //https://check.torproject.org
    final sock = await RawSocket.connect(InternetAddress.loopbackIPv4, 9050);
    final s = SOCKSSocket(sock);
    const String host = "check.torproject.org";

    await s.connect("$host:80");

    //Doesnt work
    final ss = await RawSecureSocket.secure(sock, host: host);

    await httpsGet(ss, s, host);

    await s.close(keepOpen: false);
  });*/
}
