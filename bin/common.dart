
import 'dart:io' show Platform;
import 'package:sprintf/sprintf.dart' show sprintf;
import 'package:dping4mtr/dping4mtr.dart' show Ping;

typedef TsUsec = ({int sec, int usec}); // timestamp: sec, usec
final myname = (Platform.executable == 'dart') ? 'dmtr' : Platform.executable;

// as a record to be synced
typedef HopData = ({int sent, int rcvd, int last, int best, int wrst, double avg, double jttr}); // last,best,wrst,avg in usec

const hostnameLen = 30; // TMP [report mode]

final hostTitle = 'Host'; // left(host) part of output
const _statfmt = '%-4s %-5s %-4s %-4s %-4s  %-4s %-4s';
final statTitle = sprintf(_statfmt, ['Loss', 'Sent', 'Last', 'Best', 'Wrst', 'Avrg', 'Jttr']);
final statMax = sprintf(_statfmt, List<String>.filled(7, '')).length;

class Hop {
  HopData data = (sent: 0, rcvd: 0, last: 0, best: 0, wrst: 0, avg: 0, jttr: 0);
  String? addr;
  String? name;
  Ping? ping;
  int seq = -1; // a marker to avoid dups at calculation of 'sent'
  TsUsec? ts;   // timestamp of timeouted response
  int? prtt;    // previous RTT
  String get host => (name ?? addr) ?? '';
  String get msec => (data.last > 0) ? prfmt(data.last / 1000) : '';
  String get loss => (data.sent > 0) ? '${prfmt((data.sent - data.rcvd) / data.sent * 100)}%' : '';
  String get best => (data.best > 0) ? prfmt(data.best / 1000) : '';
  String get wrst => (data.wrst > 0) ? prfmt(data.wrst / 1000) : '';
  String get avg => (data.avg > 0) ? prfmt(data.avg / 1000) : '';
  String get jttr => (data.jttr > 0) ? prfmt(data.jttr / 1000) : '';
  String get lpart => host;
  String get rpart => (data.sent > 0) ? sprintf(_statfmt, [loss, '${data.sent}', msec, best, wrst, avg, jttr]) : '';
  @override
  String toString() => sprintf('%-*.*s %s', [hostnameLen, hostnameLen, lpart, rpart]);
}

const floatUpto = 10;
String prfmt(double v) => sprintf('%.*f', [((v > 0) && (v < floatUpto)) ? ((v < 0.1) ? 2 : 1) : 0, v]);

