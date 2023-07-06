
import 'dart:io' show Platform;
import 'package:sprintf/sprintf.dart';
import 'package:dart_ping/dart_ping.dart';

const hostnameLen = 30;
typedef TsUsec = ({int sec, int usec}); // timestamp: sec, usec

final myname = (Platform.executable == 'dart') ? 'dmtr' : Platform.executable;

class Hop {
  int sent = 0;
  int rcvd = 0;
  int last = 0; // in usec
  String? addr;
  String? name;
  //
  Ping? ping;
  int disc = -1; // to avoid dups at calculation of 'sent'
  TsUsec? ts;    // timestamp of timeouted response
  @override
  String toString() {
    final hop = (name ?? addr) ?? '';
    String l = (last > 0) ? sprintf("%.1f", [last / 1000]) : '-';
    return sprintf('%-*s\t%d\t%d\t%s', [hostnameLen, hop, sent, rcvd, l]);
  }
}

