
import 'package:sprintf/sprintf.dart' show sprintf;
import 'sysping.dart' show Ping;
import 'params.dart';
import 'aux.dart';

typedef TsUsec = ({int sec, int usec}); // timestamp: sec, usec

// Data per hop (as a record to be synced)
// note: last,best,wrst,avg in usec
typedef HopData = ({int sent, int rcvd, int last, int best, int wrst, double avg, double jttr});

int maxHostaddr = 0, maxHostname = 0;
const maxNamesPerHop = 5;

class Hop {
  HopData data = (sent: 0, rcvd: 0, last: 0, best: 0, wrst: 0, avg: 0, jttr: 0);
  List<String?> addr = [];
  List<String?> name = [];
  Ping? ping;
  int seq = -1; // a marker to avoid dups at calculation of 'sent'
  TsUsec? ts;   // timestamp of timeouted response
  int? prtt;    // previous RTT
  bool unreach = false; // unreachable
  String? wrong;        // message with what's wrong
  String host(int n) => dnsEnable ? ((name[n] ?? addr[n]) ?? '') : (addr[n] ?? '');
  String get loss => (data.sent > 0) ? '${prfmt((data.sent - data.rcvd) / data.sent * 100)}%' : '';
  String get msec => (data.rcvd > 0) ? (_ok ? prfmt(data.last / 1000) : '') : '';
  String get best => (data.rcvd > 0) ? (_ok ? prfmt(data.best / 1000) : '') : '';
  String get wrst => (data.rcvd > 0) ? (_ok ? prfmt(data.wrst / 1000) : '') : '';
  String get avg  => (data.rcvd > 0) ? (_ok ? prfmt(data.avg / 1000) : '') : '';
  String get jttr => (data.rcvd > 1) ? (_ok ? prfmt(data.jttr / 1000) : '') : '';
  String lpart(int n) => (n < addr.length) ? host(n) : '';
  String get rpart => (data.sent > 0) ? sprintf(statfmt, [loss, '${data.sent}', msec, best, wrst, avg, jttr]) : '';
  bool get _ok => (data.wrst != 0);
  @override
  String toString() {
    int l = dnsEnable ? maxHostname : maxHostaddr;
    return sprintf('%-*.*s %s', [l, l, lpart(0), rpart]);
  }
}

void cleanNonStat(Hop h) { h.ping = h.ts = h.prtt = null; h.seq = -1; h.unreach = false; }

