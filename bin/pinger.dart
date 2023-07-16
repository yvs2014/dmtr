
import 'dart:io' show sleep;
import 'dart:async' show Timer;
import 'common.dart';
import 'dcurses.dart';
import 'sysping.dart' show Ping, Data, Status;

const _maxTtl = 30;

late int hops;
late List<Hop> stat;

void resetPings() {
  hops = _maxTtl;
  stat = List<Hop>.generate(_maxTtl, (_) => Hop());
  maxHostaddr = maxHostname = 0;
}

void resetStats() {
  hops = _maxTtl;
  for (int i = 0; i < hops; i++) {
    stat[i].data = (sent: 0, rcvd: 0, last: 0, best: 0, wrst: 0, avg: 0, jttr: 0);
  }
  maxHostaddr = maxHostname = 0;
}

bool _postclearNote = false;

void _keyActions(String host) {
  if (_postclearNote) { addnote = null; _postclearNote = false; }
  String? c = getKey();
  if (c?.isNotEmpty ?? false) {
    switch (c!.toLowerCase()) {
      case 'd': if (!numeric) dnsEnable = !dnsEnable;
      case 'h': keyHelp(); showStat(stat, hops, host);
      case 'p': pause = !pause; addnote = pause ? ': in pause' : null;
      case 'q':
        for (int i = 0; i < _maxTtl; i++) { stat[i].ping?.stop(); }
        addnote = ': quitting...';
      case 'r': resetStats(); addnote = ': resetting...'; _postclearNote = true;
      case 't': addnote = ': first-ttl not yet'; _postclearNote = true; // TODO later
    }
  }
}

Future<void> pingHops(String host) async {
  resetPings();
  List<Future<void>> input = [];
  Timer? timer;
  if (displayMode) timer = Timer.periodic(Duration(seconds: timeout), (_) { showStat(stat, hops, host); _keyActions(host); });
  for (int i = 0; i < _maxTtl; i++) {
    int ttl = i + 1;
    stat[i].ping = Ping(host, ttl: ttl, count: count, dt: timeout, dns: dnsEnable);
    var p = stat[i].ping;
    if (p != null) input.add(_readEvents(ttl, p.data));
  }
  await Future.wait(input);
  if (displayMode) {
    sleep(Duration(milliseconds: timeout * 1000 ~/ 2));
    timer?.cancel();
    showStat(stat, hops, host);
    sleep(Duration(milliseconds: 500)); // 0.5sec enough to spot last updates
  }
}


Future<void> _readEvents(int ttl, var stream) async {
  await for (final data in stream) {
    if (data != null) {
      int ndx = ttl - 1;
      switch (data.status) {
        case Status.success:
          if ((data.ttl != null) && (hops > ttl)) { // 'data.ttl' is only at target
            hops = ttl; // stop pings at this ttl
            for (int i = hops; i < _maxTtl; i++) { stat[i].ping?.stop(); }
          }
          _setHopData(ndx, data);
        case Status.discard:
          _setHopData(ndx, data);
        case Status.timeout:
          if (stat[ndx].seq != data.seq) stat[ndx].data = _incHopDataSent(ndx);
          stat[ndx].seq = 0;
          stat[ndx].ts = (data.ts != null) ? _parseTs(data.ts) : null; // keep it for possible future discard
        case Status.unknown: // unknown host: stop all pings
          hops = 0;
          for (int i = 0; i < _maxTtl; i++) { stat[i].ping?.stop(); }
          fail = data.mesg?.replaceFirst('ping: ', '');
          return;
//        case Status.error:
//          fail = 'Got error: ${data.mesg}';
      }
      // at ping-exit take into account the last timeout
      if ((data.rc != null) && (stat[ndx].seq == 0)) stat[ndx].data = _incHopDataSent(ndx);
    }
  }
}


HopData _incHopDataSent(int ndx) => (sent: stat[ndx].data.sent + 1, rcvd: stat[ndx].data.rcvd,
  last: stat[ndx].data.last, best: stat[ndx].data.best, wrst: stat[ndx].data.wrst,
  avg: stat[ndx].data.avg, jttr: stat[ndx].data.jttr);

void _setHopData(int ndx, Data data) {
  int? last;
  if (data.time != null) {
    last = data.time?.inMicroseconds;
  } else {
    if ((data.ts != null) && (stat[ndx].ts != null)) {
      TsUsec tu = _parseTs(data.ts!);
      last = ((tu.sec - stat[ndx].ts!.sec) * 1000000 + (tu.usec - stat[ndx].ts!.usec)).toInt();
    }
  }
  if (data.addr != null) _addAddrNameAt(ndx, data.addr!, data.name);
  if (data.seq != null) stat[ndx].seq = data.seq!; // marker of stats
  int sent = stat[ndx].data.sent + 1;
  int rcvd = stat[ndx].data.rcvd + 1;
  int best = stat[ndx].data.best;
  int wrst = stat[ndx].data.wrst;
  double avg  = stat[ndx].data.avg;
  double jttr = stat[ndx].data.jttr;
  if (last != null) {
    if (last > wrst) wrst = last;
    if ((last < best) || (best == 0)) best = last;
    avg += (last - avg) / rcvd;
    if ((stat[ndx].prtt != null) && (rcvd > 1)) {
      int j = (last - stat[ndx].prtt!).abs();
      jttr += (j - jttr) / (rcvd - 1);
    }
    stat[ndx].prtt = last;
  }
  stat[ndx].data = (sent: sent, rcvd: rcvd, last: last ?? stat[ndx].data.last, best: best, wrst: wrst, avg: avg, jttr: jttr);
}


TsUsec _parseTs(String s) {
  var a = s.split('.');
  int sec = 0, usec = 0;
  if (a.length == 2) { sec = int.parse(a[0]); usec = int.parse(a[1]); }
  if (a.length == 1) sec = int.parse(a[0]);
  return (sec: sec, usec: usec);
}

void _addAddrNameAt(int ndx, String addr, String? name) {
  final an = stat[ndx].addr.indexWhere((a) => ((a != null) ? (a == addr) : false));
  if (an < 0) { // new addr
    if (stat[ndx].addr.length >= maxNamesPerHop) { stat[ndx].addr.removeAt(0); stat[ndx].name.removeAt(0); }
    stat[ndx].addr.add(addr);
    stat[ndx].name.add(name);
    if (addr.length > maxHostaddr) maxHostaddr = addr.length;
    if (maxHostaddr > maxHostname) maxHostname = maxHostaddr;
    if ((name != null) && (name.length > maxHostname)) maxHostname = name.length;
  } else if ((stat[ndx].name[an] == null) && (name != null)) { // if name is not set before
    stat[ndx].name[an] = name;
    if (name.length > maxHostname) maxHostname = name.length;
  }
}

