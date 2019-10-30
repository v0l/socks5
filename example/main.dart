import 'dart:io';

import 'package:socks5/socks5.dart';

void main() async {
  /// [SOCKSSocket] uses a raw socket to authorize
  /// and request a connection, connect to your socks proxy server
  final sock = await RawSocket.connect(InternetAddress.loopbackIPv4, 9050);

  /// pass the socket to [SOCKSSocket]
  final proxy = SOCKSSocket(sock);

  /// request the proxy to connect to a host
  /// this call will throw exceptions if connection attempt fails from the proxy
  await proxy.connect("google.com:80");

  /// Now you can use the [sock] from earlier, since we can only listen
  /// once on a [RawSocket] we must set the [onData] function to intercept
  /// the events from the socket
  proxy.subscription.onData((RawSocketEvent event) {
    /// [RawSocketEvent] messages are here
    /// read from here..
    if (event == RawSocketEvent.read) {
      final data = sock.read(sock.available());
      print("Got ${data.length} bytes");
    }
  });

  /// To connect with an [InternetAddress] use:
  /// await s.connectIp(InternetAddress.loopbackIPv4, 80);

  /// keepOpen=false will call close the [RawSocket]
  await proxy.close(keepOpen: false);
}
