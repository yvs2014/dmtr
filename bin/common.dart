
import 'dart:io' show Platform;
import 'package:sprintf/sprintf.dart' show sprintf;
import 'package:dping4mtr/dping4mtr.dart' show Ping;

typedef TsUsec = ({int sec, int usec}); // timestamp: sec, usec
final myname = (Platform.executable == 'dart') ? 'dmtr' : Platform.executable;
final version = '0.1.4';
String? optstr;
String? title;
bool pause = false;
String? addnote;

// as a record to be synced
typedef HopData = ({int sent, int rcvd, int last, int best, int wrst, double avg, double jttr}); // last,best,wrst,avg in usec

final hostTitle = 'Hops'; // left(host) part of output
const _statfmt = '%-4s %-5s %-4s %-4s %-4s  %-4s %-4s';
final statTitle = sprintf(_statfmt, ['Loss', 'Sent', 'Last', 'Best', 'Wrst', 'Avrg', 'Jttr']);
final statMax = sprintf(_statfmt, List<String>.filled(7, '')).length;
int maxHostaddr = 0, maxHostname = 0;
const lindent = 4; // lpart's indent

// options can be reset with program args, below are defaults
bool dnsEnable = true;     // -n
bool reportEnable = false; // -r
int timeout = 1;           // -w seconds
int? count;                // -c count
bool numeric = false;      // not toggled dnsEnable

const maxNamesPerHop = 5;

class Hop {
  HopData data = (sent: 0, rcvd: 0, last: 0, best: 0, wrst: 0, avg: 0, jttr: 0);
  List<String?> addr = [];
  List<String?> name = [];
  Ping? ping;
  int seq = -1; // a marker to avoid dups at calculation of 'sent'
  TsUsec? ts;   // timestamp of timeouted response
  int? prtt;    // previous RTT
  String host(int n) => dnsEnable ? ((name[n] ?? addr[n]) ?? '') : (addr[n] ?? '');
  String get msec => (data.rcvd > 0) ? prfmt(data.last / 1000) : '';
  String get loss => (data.sent > 0) ? '${prfmt((data.sent - data.rcvd) / data.sent * 100)}%' : '';
  String get best => (data.rcvd > 0) ? prfmt(data.best / 1000) : '';
  String get wrst => (data.rcvd > 0) ? prfmt(data.wrst / 1000) : '';
  String get avg => (data.rcvd > 0) ? prfmt(data.avg / 1000) : '';
  String get jttr => (data.rcvd > 1) ? prfmt(data.jttr / 1000) : '';
  String lpart(int n) => (n < addr.length) ? host(n) : '';
  String get rpart => (data.sent > 0) ? sprintf(_statfmt, [loss, '${data.sent}', msec, best, wrst, avg, jttr]) : '';
  @override
  String toString() {
    int l = dnsEnable ? maxHostname : maxHostaddr;
    return sprintf('%-*.*s %s', [l, l, lpart(0), rpart]);
  }
}

const floatUpto = 10;
const twoDigitsUpto = 0.1;
String prfmt(double v) => sprintf('%.*f', [((v > 0) && (v < floatUpto)) ? ((v < twoDigitsUpto) ? 2 : 1) : 0, v]);
void setTitle(String host) { title = ['$myname-$version', optstr, host].where((a) => (a != null) && a.isNotEmpty).join(' '); }

