
import 'dart:io' show sleep;
import 'dart:async' show Timer;
import 'package:dping4mtr/dping4mtr.dart' show Ping, PingResponse, ErrorType, ReStatus;
import 'common.dart';
import 'dcurses.dart';

const waitTimeout = 1; // in seconds
const dnsResolve = true;
const maxTtl = 30;

late int hops;
late List<Hop> stat;
bool _stopFlag = false;

void resetStat() {
  hops = maxTtl;
  stat = List<Hop>.generate(maxTtl, (_) => Hop());
}

Future <void> runDisplay({int timeout = waitTimeout}) async {
  Timer.periodic(Duration(seconds: timeout), (timer) {
    if (_stopFlag) { timer.cancel(); }
    else {
      String? c = getKey();
      if (c?.isNotEmpty ?? false) {
        switch (c) {
          case 'q': for (int i = 0; i < maxTtl; i++) { stat[i].ping?.stop(); }
//          default: print("key='$c'");
        }
      }
      showStat(stat: stat, hops: hops);
    }
  });
}

Future <void> pingHops({required String host, int? count, int timeout = waitTimeout, bool dns = dnsResolve, bool silent = false}) async {
  resetStat();
  if (!silent) { openDisplay(); setDisplayHost(host); runDisplay(); }
  List<Future<void>> readers = [];
  for (int i = 0; i < maxTtl; i++) {
    int ttl = i + 1;
    stat[i].ping = Ping(host, ttl: ttl, timing: true, count: count, timeout: timeout, dns: dns);
    var p = stat[i].ping;
    if (p != null) readers.add(_readEvents(ttl, p.stream));
  }
  await Future.wait(readers).then((_) { if (!silent) { _stopFlag = true; closeDisplay(); sleep(Duration(seconds: timeout)); }});
}


Future <void> _readEvents(int ttl, var stream) async {
  await for (final ev in stream) {
//print("got[ttl=$ttl] $ev"); // TMP
    if (ev.error != null) { // got error
      if (ev.error.error == ErrorType.unknownHost) { // unknown host: stop all pings
        if (hops > 0) {
           print('$myname: ${ev.error}');
      	   hops = 0;
           for (int i = hops; i < maxTtl; i++) { stat[i].ping?.stop(); }
        }
        return;
      }
    }
    int ndx = ttl - 1;
    var re = ev.response;
    if (re != null) {
      switch (re?.status) {
        case ReStatus.success:
          if ((re.ttl != null) && (hops > ttl)) {
            hops = ttl; // stop pings at this ttl
            for (int i = hops; i < maxTtl; i++) { stat[i].ping?.stop(); }
          }
          _setHopData(ndx, re);
        case ReStatus.discard:
          _setHopData(ndx, re);
        case ReStatus.timeout:
          if (stat[ndx].seq != re.seq) stat[ndx].data = _incHopDataSent(ndx);
          stat[ndx].seq = 0;
          stat[ndx].ts = (re.ts != null) ? _parseTs(re.ts) : null; // keep it for possible future discard
      }
    }
    if ((ev.summary != null) && (stat[ndx].seq == 0)) stat[ndx].data = _incHopDataSent(ndx); // take into account a last timeout
  }
}


HopData _incHopDataSent(int ndx) => (sent: stat[ndx].data.sent + 1, rcvd: stat[ndx].data.rcvd,
  last: stat[ndx].data.last, best: stat[ndx].data.best, wrst: stat[ndx].data.wrst,
  avg: stat[ndx].data.avg, jttr: stat[ndx].data.jttr);

void _setHopData(int ndx, PingResponse re) {
  int? last;
  if (re.time != null) {
    last = re.time?.inMicroseconds;
  } else {
    if ((re.ts != null) && (stat[ndx].ts != null)) {
      TsUsec tu = _parseTs(re.ts!);
      last = ((tu.sec - stat[ndx].ts!.sec) * 1000000 + (tu.usec - stat[ndx].ts!.usec)).toInt();
    }
  }
  if (re.ip != null) stat[ndx].addr = re.ip;
  if (re.name != null) stat[ndx].name = re.name;
  if (re.seq != null) stat[ndx].seq = re.seq!; // marker of stats
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
      int dj = (last - stat[ndx].prtt!).abs();
      jttr += (dj - jttr) / (rcvd - 1);
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

