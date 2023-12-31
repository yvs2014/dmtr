
import 'package:sprintf/sprintf.dart' show sprintf;
import 'sysping.dart' show Ping;
import 'riswhois.dart' show RIS, who2info;
import 'params.dart';
import 'aux.dart';

typedef TsUsec = ({int sec, int usec}); // timestamp: sec, usec

// Host info: ip address, resolved hostname, whois info
typedef HostInfo = ({String? addr, String? name, RIS? whois});

// Data per hop (as a record to be synced)
// note: last,best,wrst,avg in usec
typedef HopData = ({int sent, int rcvd, int last, int best, int wrst, double avg, double jttr});

int maxHostaddr = 0, maxHostname = 0;
const maxNamesPerHop = 5;

bool running = false;

HopData get _zeroData => (sent: 0, rcvd: 0, last: 0, best: 0, wrst: 0, avg: 0.0, jttr: 0.0);

class Hop {
  HopData data = _zeroData;
  List<HostInfo> info = [];
  Ping? ping;
  int seq = -1; // a marker to avoid dups at calculation of 'sent'
  TsUsec? ts;   // timestamp of timeouted response
  int? prtt;    // previous RTT
  bool reachable = true;
  String? wrong;        // message with what's wrong
  Set<int> reslock = {}; // resolv in progress for indexes in set
  Set<int> whoislock = {}; // whois query in progress for indexes in set
  String? _ha(int n) => (info[n].name ?? '').isEmpty ? info[n].addr : info[n].name;
  String host(int n) => (dnsEnable ? _ha(n) : info[n].addr) ?? '';
  String get loss => (data.sent > 0) ? '${prfmt((data.sent - data.rcvd) / data.sent * 100)}%' : '';
  String get msec => (data.rcvd > 0) ? (_ok ? prfmt(data.last / 1000) : '') : '';
  String get best => (data.rcvd > 0) ? (_ok ? prfmt(data.best / 1000) : '') : '';
  String get wrst => (data.rcvd > 0) ? (_ok ? prfmt(data.wrst / 1000) : '') : '';
  String get avg  => (data.rcvd > 0) ? (_ok ? prfmt(data.avg / 1000) : '') : '';
  String get jttr => (data.rcvd > 1) ? (_ok ? prfmt(data.jttr / 1000) : '') : '';
  String addrname(int n) => (n < info.length) ? host(n) : '';
  String who(int n) => (n < info.length) ? who2info(info[n].whois) : '';
  String lpart(int n) {
    if (n >= info.length) return '';
    var a = addrname(n);
    if (whoKeys != null) { var extra = who(n); if (extra.isNotEmpty) return '$extra $a'; }
    return a;
  }
  String get rpart => (data.sent > 0) ? rpartFn({'l': loss, 's': '${data.sent}',
    'm': msec, 'b': best, 'w': wrst, ' ': '', 'a': avg, 'j': jttr,
  }) : '';
  bool get _ok => (data.wrst != 0);
  @override
  String toString() {
    int l = dnsEnable ? maxHostname : maxHostaddr;
    if (whoKeys != null) { int dl = hostTitle.length - hopTitle.length; l += dl; }
    return sprintf('%-*.*s %s', [l, l, lpart(0), rpart]);
  }
  void clearData() { info = []; data = _zeroData; }
  void clearNonData() { ping = ts = prtt = null; seq = -1; reachable = true; }
  Future<void> stop() async { await ping?.stop(); clearNonData(); }
}

get hostPartLen {
  int l = dnsEnable ? maxHostname : maxHostaddr;
  return (whoKeys != null) ? (l + hostTitle.length - hopTitle.length) : l;
}

