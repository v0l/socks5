library socks;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'dart:typed_data';

/// https://tools.ietf.org/html/rfc1928
///

class AuthMethods {
  static const NoAuth = const AuthMethods._(0x00);
  static const GSSApi = const AuthMethods._(0x01);
  static const UsernamePassword = const AuthMethods._(0x02);
  static const NoAcceptableMethods = const AuthMethods._(0xFF);

  final int _value;

  const AuthMethods._(this._value);

  String toString() {
    return const [
      'AuthMethods.NoAuth',
      'AuthMethods.GSSApi',
      'AuthMethods.UsernamePassword',
      'AuthMethods.NoAcceptableMethods'
    ][_value];
  }
}

class SOCKSState {
  static const Starting = const SOCKSState._(0x00);
  static const Auth = const SOCKSState._(0x01);
  static const RequestReady = const SOCKSState._(0x02);
  static const Connected = const SOCKSState._(0x03);

  final int _value;

  const SOCKSState._(this._value);

  String toString() {
    return const [
      'SOCKSState.Starting',
      'SOCKSState.Auth',
      'SOCKSState.RequestReady',
      'SOCKSState.Connected',
    ][_value];
  }
}

class SOCKSAddressType {
  static const IPv4 = const SOCKSAddressType._(0x01);
  static const Domain = const SOCKSAddressType._(0x03);
  static const IPv6 = const SOCKSAddressType._(0x04);

  final int _value;

  const SOCKSAddressType._(this._value);

  String toString() {
    return const ['SOCKSAddressType.IPv4', 'SOCKSAddressType.Domain', 'SOCKSAddressType.IPv6'][_value];
  }
}

class SOCKSCommand {
  static const Connect = const SOCKSCommand._(0x01);
  static const Bind = const SOCKSCommand._(0x02);
  static const UDPAssociate = const SOCKSCommand._(0x03);

  final int _value;

  const SOCKSCommand._(this._value);

  String toString() {
    return const ['SOCKSCommand.Connect', 'SOCKSCommand.Bind', 'SOCKSCommand.UDPAssociate'][_value];
  }
}

class SOCKSReply {
  static const Success = const SOCKSReply._(0x00);
  static const GeneralFailure = const SOCKSReply._(0x01);
  static const ConnectionNotAllowedByRuleset = const SOCKSReply._(0x02);
  static const NetworkUnreachable = const SOCKSReply._(0x03);
  static const HostUnreachable = const SOCKSReply._(0x04);
  static const ConnectionRefused = const SOCKSReply._(0x05);
  static const TTLExpired = const SOCKSReply._(0x06);
  static const CommandNotSupported = const SOCKSReply._(0x07);
  static const AddressTypeNotSupported = const SOCKSReply._(0x08);

  final int _value;

  const SOCKSReply._(this._value);

  String toString() {
    return const [
      'SOCKSReply.Success',
      'SOCKSReply.GeneralFailure',
      'SOCKSReply.ConnectionNotAllowedByRuleset',
      'SOCKSReply.NetworkUnreachable',
      'SOCKSReply.HostUnreachable',
      'SOCKSReply.ConnectionRefused',
      'SOCKSReply.TTLExpired',
      'SOCKSReply.CommandNotSupported',
      'SOCKSReply.AddressTypeNotSupported'
    ][_value];
  }
}

class SOCKSRequest {
  final int version = 0x05;
  final SOCKSCommand command;
  final SOCKSAddressType addressType;
  final Uint8List address;
  final int port;

  SOCKSRequest({
    this.command,
    this.addressType,
    this.address,
    this.port,
  });
}

class SOCKSSocket {
  List<AuthMethods> _auth;
  int _remotePort;
  InternetAddress _remoteIp;
  RawSocket _sock;
  StreamSubscription _sockSub;
  SOCKSState _state;
  SOCKSRequest _request;

  Future get waitForExit => _sockSub?.asFuture();
  RawSocket get socket => _sock;

  SOCKSSocket(
    InternetAddress ip, {
    int port = 1080,
    List<AuthMethods> auth = const [AuthMethods.NoAuth],
  }) {
    _remoteIp = ip;
    _auth = auth;
    _remotePort = port ?? 1080;
    _state = SOCKSState.Starting;
  }

  Future connect(String domain) async {
    final ds = domain.split(':');
    assert(ds.length == 2, "Domain must contain port, example.com:80");

    _request = SOCKSRequest(
      command: SOCKSCommand.Connect,
      addressType: SOCKSAddressType.Domain,
      address: AsciiEncoder().convert(ds[0]).sublist(0, ds[0].length),
      port: int.tryParse(ds[1]) ?? 80,
    );
    await _start();
  }

  Future _start() async {
    _sock = await RawSocket.connect(_remoteIp, _remotePort);

    // send auth methods
    _state = SOCKSState.Auth;
    _sock.write([
      0x05,
      _auth.length,
      ..._auth.map((v) => v._value),
    ]);

    _sockSub = _sock.listen((RawSocketEvent ev) {
      print(ev);
      switch (ev) {
        case RawSocketEvent.read:
          {
            final have = _sock.available();
            print("Reading: $have");

            final data = _sock.read(have);
            print(data);

            _handleRead(data);
            break;
          }
      }
    });
  }

  void _handleRead(Uint8List data) {
    if (_state == SOCKSState.Auth) {
      if (data.length == 2) {
        final version = data[0];
        final auth = AuthMethods._(data[1]);

        print("Version: ${version}, Auth: ${auth}");

        _state = SOCKSState.RequestReady;
        _writeRequest(_request);
      } else {
        throw "Expected 2 bytes";
      }
    } else if (_state == SOCKSState.RequestReady) {
      if (data.length >= 10) {
        final version = data[0];
        final reply = SOCKSReply._(data[1]);
        //data[2] reserved
        final addrType = SOCKSAddressType._(data[3]);
        Uint8List addr;
        var port = 0;

        if (addrType == SOCKSAddressType.Domain) {
          final len = data[4];
          addr = data.sublist(5, 5 + len);
          port = data[5 + len] << 8 | data[6 + len];
        } else if (addrType == SOCKSAddressType.IPv4) {
          addr = data.sublist(5, 9);
          port = data[9] << 8 | data[10];
        } else if (addrType == SOCKSAddressType.IPv6) {
          addr = data.sublist(5, 21);
          port = data[21] << 8 | data[22];
        }

        print("Version: $version, Reply: $reply, AddrType: $addrType, Addr: $addr, Port: $port");
        if (reply._value == SOCKSReply.Success._value) {
          _state = SOCKSState.Connected;
          _sockSub.cancel(); //disconnect our socket listener
        } else {
          throw reply.toString();
        }
      } else {
        throw "Expected 10 bytes";
      }
    }
  }

  int _getRequestSize(SOCKSRequest req) {
    final varlen = () {
      if (req.addressType == SOCKSAddressType.IPv4) {
        return 4;
      } else if (req.addressType == SOCKSAddressType.IPv6) {
        return 16;
      } else if (req.addressType == SOCKSAddressType.Domain) {
        return 1 + req.address.lengthInBytes - 1;
      }
      return 0;
    }();
    return 6 + varlen;
  }

  void _writeRequest(SOCKSRequest req) {
    if (_state == SOCKSState.RequestReady) {
      if (req.addressType == SOCKSAddressType.IPv4) {}
      final data = [
        req.version,
        req.command._value,
        0x00,
        req.addressType._value,
        if (req.addressType == SOCKSAddressType.Domain) req.address.lengthInBytes,
        ...req.address,
        req.port >> 8,
        req.port & 0xF,
      ];
      print(data);
      _sock.write(data);
    } else {
      throw "Must be in RequestReady state, current state ${_state}";
    }
  }
}
