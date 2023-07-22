
import 'dart:io' show sleep;
import 'dart:async' show Timer;
import 'package:collection/collection.dart' show IterableNullableExtension;
import 'common.dart';
import 'dcurses.dart';
import 'sysping.dart' show Ping, Data, Status;

late int _hops;
int get hops => _hops;
List<Hop> stat = [];
var _futures = List<Future<void>?>.filled(maxTTL, null, growable: false); // ping futures
bool _futureslocked = false;


void _resetPings() {
  _hops = maxTTL;
  stat = List<Hop>.generate(maxTTL, (_) => Hop());
  maxHostaddr = maxHostname = 0;
}

void _resetStats() {
  for (int i = 0; i < maxTTL; i++) {
    stat[i].data = (sent: 0, rcvd: 0, last: 0, best: 0, wrst: 0, avg: 0, jttr: 0);
  }
  _hops = maxTTL;
  maxHostaddr = maxHostname = 0;
}

void _stopPingAt(int at) {
  if (stat[at].ping == null) return;
  logger?.p('stop ping[ttl=${at + 1}]');
  stat[at].ping?.stop();
  cleanNonStat(stat[at]);
  _futures[at] = null;
}

TsUsec? _parseTS(String s) {
  try {
    var a = s.split('.');
    int sec = 0, usec = 0;
    if (a.length == 2) { sec = int.parse(a[0]); usec = int.parse(a[1]); }
    if (a.length == 1) sec = int.parse(a[0]);
    return (sec: sec, usec: usec);
  } catch (e) { print('(Cannot parse TS: $e)'); }
  return null;
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

void _setHopData(int ndx, Data data) {
  if (!gotdata) gotdata = true;
  if (stat[ndx].unreach) stat[ndx].unreach = false;
  int? last;
  if (data.time != null) {
    last = data.time?.inMicroseconds;
  } else {
    var prev = stat[ndx].ts, currStr = data.ts;
    if ((prev != null) && (currStr != null)) {
      var curr = _parseTS(currStr);
      if (curr == null) return;
      last = ((curr.sec - prev.sec) * 1000000 + (curr.usec - prev.usec)).toInt();
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
    var prev = stat[ndx].prtt;
    if ((prev != null) && (rcvd > 1)) {
      int j = (last - prev).abs();
      jttr += (j - jttr) / (rcvd - 1);
    }
    stat[ndx].prtt = last;
  }
  stat[ndx].data = (sent: sent, rcvd: rcvd, last: last ?? stat[ndx].data.last, best: best, wrst: wrst, avg: avg, jttr: jttr);
}

HopData _incHopDataSent(int ndx) => (sent: stat[ndx].data.sent + 1, rcvd: stat[ndx].data.rcvd,
  last: stat[ndx].data.last, best: stat[ndx].data.best, wrst: stat[ndx].data.wrst,
  avg: stat[ndx].data.avg, jttr: stat[ndx].data.jttr);

int _ndxBackOfUnreach(int ndx) {
  for (int i = ndx; i > 0; i--) {
    if (!stat[i - 1].unreach) return i;
  }
  return 0;
}

Future<void> _readEvents(int ttl, var stream) async {
  await for (final data in stream) {
    if (data != null) {
      int ndx = ttl - 1;
      if (stat[ndx].ping == null) continue; // it's already stopped, don't stat it
      switch (data.status) {
        case Status.success:
          if ((data.ttl != null) && (_hops > ttl)) { // 'data.ttl' is only at target
            _hops = ttl; // stop pings at this ttl
            for (int i = _hops; i < maxTTL; i++) { _stopPingAt(i); }
          }
          _setHopData(ndx, data);
        case Status.discard:
          _setHopData(ndx, data);
          if (data.mesg?.contains('nreachable') || false) {
            stat[ndx].unreach = true;
            int lastndx = (lastTTL < _hops) ? lastTTL : _hops;
            if ((lastndx == ttl) && (lastndx > 0)) _hops = _ndxBackOfUnreach(ndx) + 1;
          }
        case Status.timeout:
          if (stat[ndx].seq != data.seq) stat[ndx].data = _incHopDataSent(ndx);
          stat[ndx].seq = 0;
          stat[ndx].ts = (data.ts != null) ? _parseTS(data.ts) : null; // keep timestamp for possible future discards
        case Status.unknown: // unknown host: stop all pings
          _hops = 0;
          for (int i = 0; i < maxTTL; i++) { stat[i].ping?.stop(); }
          fail = data.mesg?.replaceFirst('ping: ', '');
          return;
        case Status.error:
          var emesg = (data.mesg != null) ? ': ${data.mesg}' : '';
          logger?.p('Got error$emesg');
          if (data.mesg != null) addGlobalErr(data.mesg);
      }
      // take into account the last timeout at ping exit
      if ((data.rc != null) && (stat[ndx].seq == 0)) stat[ndx].data = _incHopDataSent(ndx);
    }
  }
  _futures[ttl - 1] = null; // cleanup its future
}

void _futuresInRange(String host, int min, int max) {
  _futureslocked = true;
  min -= 1; max = (max > _hops) ? _hops : max;
  for (int i = min; i < max; i++) { // firstly add new ones
    if (stat[i].ping == null) {
      int ttl = i + 1;
      int? cnt = count;
      if ((stat[i].data.sent > 0) && (cnt != null)) cnt -= stat[i].data.sent;
      Ping? p;
      if ((cnt == null) || (cnt > 0)) p = Ping(host, interval: interval, ttl: ttl, count: cnt, numeric: !dnsEnable, ipv4: ipv4only, ipv6: ipv6only);
      if (p != null) {
        stat[i].ping = p;
        _futures[i] = _readEvents(ttl, p.data);
        logger?.p('add ping[$i] ${p.args}');
      }
    } else { _futures[i] = null; }
  }
  // then stop unused
  for (int i = 0; i < min; i++) { _stopPingAt(i); }
  for (int i = max; i < maxTTL; i++) { _stopPingAt(i); }
  _futureslocked = false;
}

bool _postclearNote = false;

void _keyActions(String host) {
  if (_postclearNote) { addnote = null; _postclearNote = false; }
  switch (getKey()) {
    case 'd': if (!numeric) dnsEnable = !dnsEnable;
      logger?.p("action 'dns': dnsEnable=$dnsEnable");
    case 'h': keyHelp(); showStat(host, stat, _hops);
      logger?.p("action 'help'");
    case 'p': pause = !pause; addnote = pause ? ': in pause' : null;
      logger?.p("action 'pause': pause=$pause");
    case 'q':
      logger?.p("action 'quit'");
      addnote = ': quitting...';
      for (int i = 0; i < maxTTL; i++) { _stopPingAt(i); }
    case 'r': _resetStats(); addnote = ': resetting...'; _postclearNote = true;
    case 't':
      logger?.p("action 'ttl'");
      keyTTL();
      logger?.p('new ttl range: $firstTTL..$lastTTL');
      _postclearNote = true;
      _futuresInRange(host, firstTTL, lastTTL);
      showStat(host, stat, _hops);
  }
}

Future<void> pingHops(String host) async {
  _resetPings();
  Timer? pingTimer, kbdTimer;
  if (displayMode) {
    pingTimer = Timer.periodic(Duration(seconds: interval), (_) => showStat(host, stat, _hops));
    kbdTimer = Timer.periodic(Duration(milliseconds: 100), (_) => _keyActions(host));
  }
  _futuresInRange(host, firstTTL, lastTTL);
  logger?.p("ping '$host' is started (interval=${interval}sec cycles=${count ?? 'nolimit'})");
  while (_futures.whereNotNull().isNotEmpty) {
    await Future.wait(_futures.whereNotNull()); while (_futureslocked) {}
  }
  logger?.p("ping '$host' is finished");
  if (displayMode) {
    sleep(Duration(milliseconds: interval * 1000 ~/ 2));
    pingTimer?.cancel();
    kbdTimer?.cancel();
    showStat(host, stat, _hops);
    sleep(Duration(milliseconds: 500)); // 0.5sec enough to spot last updates
  }
}

