
import 'dart:io' show Platform;
import 'package:sprintf/sprintf.dart';
import 'package:dart_ping/dart_ping.dart';

const hostnameLen = 30;
typedef TsUsec = ({int sec, int usec}); // timestamp: sec, usec

final myname = (Platform.executable == 'dart') ? 'dmtr' : Platform.executable;

typedef HopData = ({int sent, int rcvd, int last/*in usec*/}); // as a record to be synced

class Hop {
  HopData data = (sent: 0, rcvd: 0, last: 0);
  String? addr;
  String? name;
  Ping? ping;
  int seq = -1;  // a marker to avoid dups at calculation of 'sent'
  TsUsec? ts;    // timestamp of timeouted response
  @override
  String toString() {
    final hop = (name ?? addr) ?? '';
    String l = (data.last > 0) ? sprintf("%.1f", [data.last / 1000]) : '-';
    return sprintf('%-*s\t%d\t%d\t%s', [hostnameLen, hop, data.sent, data.rcvd, l]);
  }
}

