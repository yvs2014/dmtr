
import 'dart:io' show sleep;
import 'dart:async' show Timer, Completer;
import 'package:collection/collection.dart' show IterableNullableExtension;
import 'common.dart';
import 'params.dart';
import 'dcurses.dart';
import 'sysping.dart' show Ping, Data, Status;
import 'aux.dart' show addFail;
import 'riswhois.dart';

late int _hops;
int get hops => _hops;
List<Hop> stat = [];
var _futures = List<Future<void>?>.filled(maxTTL, null, growable: false); // ping futures
bool _futureslocked = false;
Timer? _whoisTimer;


void _clearPings() {
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

Future<void> _stopPingAt(int at, String reason) async {
  var p = stat[at].ping;
  if (p != null) {
    logger?.p('stop ping[${at + 1}], reason: $reason');
    await p.stop();
  }
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
  final an = stat[ndx].info.indexWhere((i) => ((i.addr != null) ? (i.addr == addr) : false));
  if (an < 0) { // new addr
    if (stat[ndx].info.length >= maxNamesPerHop) stat[ndx].info.removeAt(0);
    stat[ndx].info.add((addr: addr, name: name, whois: null));
    if (addr.length > maxHostaddr) maxHostaddr = addr.length;
    if (maxHostaddr > maxHostname) maxHostname = maxHostaddr;
    if ((name != null) && (name.length > maxHostname)) maxHostname = name.length;
  } else if ((stat[ndx].info[an].name == null) && (name != null)) { // if name is not set before
    stat[ndx].info[an] = (addr: stat[ndx].info[an].addr, name: name, whois: stat[ndx].info[an].whois);
    if (name.length > maxHostname) maxHostname = name.length;
  }
  if (whoKeys != null) _whoisUpdate();
}

void _saveAddrName(int ndx, Data data) {
  if (!gotdata) gotdata = true;
  if (data.addr != null) _addAddrNameAt(ndx, data.addr!, data.name);
  if (data.seq != null) stat[ndx].seq = data.seq!; // marker of stats
}

void _setHopData(int ndx, Data data) {
  _saveAddrName(ndx, data);
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
HopData _incHopDataSentRcv(int ndx) => (sent: stat[ndx].data.sent + 1, rcvd: stat[ndx].data.rcvd + 1,
  last: stat[ndx].data.last, best: stat[ndx].data.best, wrst: stat[ndx].data.wrst,
  avg: stat[ndx].data.avg, jttr: stat[ndx].data.jttr);

int _ndxFirstUnreach(int ndx) {
  for (int i = ndx; i > 0; i--) { if (!stat[i - 1].unreach) return i; }
  return 0;
}
int _ndxFirstWrong(int ndx, String cause) {
  for (int i = ndx; i > 0; i--) { if (stat[i - 1].wrong != cause) return i; }
  return 0;
}

Future<void> _readData(int ttl, Stream<Data> stream) async {
  int ndx = ttl - 1;
  Completer<void> c = Completer();
  stream.listen((data) { switch (data.status) {
    case Status.success:
      if ((data.ttl != null) && (_hops > ttl)) { // target is reached
        _hops = ttl; // stop pings at this ttl
        for (int i = _hops; i < maxTTL; i++) { _stopPingAt(i, 'success at ttl=$ttl'); }
      }
      _setHopData(ndx, data);
    case Status.discard:
      _setHopData(ndx, data);
      if (data.mesg?.contains('nreachable') ?? false) { // rewind back to last 'unreach'
        stat[ndx].unreach = true;
        int lastndx = (lastTTL < _hops) ? lastTTL : _hops;
        if ((lastndx == ttl) && (lastndx > 0)) _hops = _ndxFirstUnreach(ndx) + 1;
      }
    case Status.timeout:
      if (stat[ndx].seq != data.seq) stat[ndx].data = _incHopDataSent(ndx);
      stat[ndx].seq = 0;
      var ts = data.ts;
      stat[ndx].ts = (ts != null) ? _parseTS(ts) : null; // keep timestamp for possible future discards
    case Status.unknown: // unknown host
      _stopPingAt(ndx, 'got unknown at=$ndx');
      addFail(data.mesg);
    case Status.error: // collect errors
      addFail(data.mesg);
    case Status.wrong: // an answer, but neither success nor discard
      _saveAddrName(ndx, data);
      if (data.seq != null) stat[ndx].data = _incHopDataSentRcv(ndx);
      var wrong = data.mesg;
      stat[ndx].wrong = wrong;
      if (wrong != null) { // rewind back to the same 'wrong'
        int lastndx = (lastTTL < _hops) ? lastTTL : _hops;
        if ((lastndx == ttl) && (lastndx > 0)) _hops = _ndxFirstWrong(ndx, wrong) + 1;
      }
    case Status.finish: // take into account the last timeout at ping exit
      if (stat[ndx].seq == 0) stat[ndx].data = _incHopDataSent(ndx);
    default: {}
  }},
  onDone: () { _futures[ndx] = null; c.complete(); },
  onError: (e) => logger?.p('ping[$ttl] error: $e'));
  return c.future;
}

Future<void> _futuresInRange(String host, int min, int max, {bool reset = false}) async {
  _futureslocked = true;
  min -= 1; max = (max > _hops) ? _hops : max;
  for (int i = min; i < max; i++) { // firstly add new ones
    if (reset) await _stopPingAt(i, 'reset args');
    if (stat[i].ping == null) {
      int ttl = i + 1;
      int? cnt = count;
      if ((stat[i].data.sent > 0) && (cnt != null)) cnt -= stat[i].data.sent;
      Ping? p;
      if ((cnt == null) || (cnt > 0)) p = Ping(host, numeric: !dnsEnable, count: cnt, interval: interval, size: psize, ttl: ttl, qos: qos, payload: payload, addrface: addrface, ipv4: ipv4only, ipv6: ipv6only);
      if (p != null) {
        stat[i].ping = p;
        _futures[i] = _readData(ttl, p.data);
        logger?.p('add ping[$ttl] ${p.args}');
      } else { _futures[i] = null; }
    }
  }
  // then stop unused
  for (int i = 0; i < min; i++) { _stopPingAt(i, 'ndx < min(${min + 1})'); }
  for (int i = max; i < maxTTL; i++) { _stopPingAt(i, 'ndx > max($max)'); }
  // unlock
  _futureslocked = false;
  logger?.p('${_futures.whereNotNull().length} pings in total');
}

bool _postclearNote = false;
bool _keyProcessing = false;

void _resetPings(String host, String what, void Function() parser, String Function() inform,
    { bool reset = true, void Function()? fnOnChange }) {
  logger?.s("action '$what'");
  _keyProcessing = true; parser(); _keyProcessing = false;
  if (paramsChanged) {
    paramsChanged = false;
    _postclearNote = true;
    logger?.p(inform());
    (fnOnChange != null) ? fnOnChange() : _futuresInRange(host, firstTTL, lastTTL, reset: reset);
  } else { logger?.p('no changes in params'); }
}

String? _savedWhoKeys;

void _keyActions(String host) {
  if (_postclearNote) { addnote = null; _postclearNote = false; }
  if (_keyProcessing) return;
  switch (getKey()) {
    case 'c': _resetPings(host, 'count', keyCycles, () => 'cycles: $count');
    case 'f': keyFields();
      if (paramsChanged) { paramsChanged = false; _postclearNote = true; }
      logger?.p("action 'fields': statKeys=$statKeys");
    case 'd': if (!numeric) dnsEnable = !dnsEnable;
      logger?.p("action 'dns': dnsEnable=$dnsEnable");
    case 'i': _resetPings(host, 'interval', keyIval, () => 'interval: $interval');
    case 'p': _resetPings(host, 'payload', keyPayload, () => 'payload pattern: $payload');
    case 'q': _resetPings(host, 'qos', keyQoS, () => 'qos bits: $qos');
    case 's': _resetPings(host, 'size', keySize, () => 'payload size: $psize');
    case 't': _resetPings(host, 'ttl', keyTTL, () => 'ttl range: $firstTTL..$lastTTL', reset: false);
    case 'w':
      if (whoKeys == null) {
        whoKeys = _savedWhoKeys ?? whoKeysDef;
        _whoisTimer = Timer.periodic(const Duration(seconds: 2 * risTimeout), (_) => _whoisUpdate());
      } else {
        _savedWhoKeys = whoKeys; whoKeys = null;
        _whoisTimer?.cancel(); _whoisTimer = null;
      }
      logger?.p("action 'whois': whoKeys=$whoKeys");
    case 'W':
      _resetPings(host, 'whois', keyWhois, () => 'whois keys: "$whoKeys"', fnOnChange: () {
        _whoisTimer?.cancel();
        _whoisTimer = (whoKeys == null) ? null : Timer.periodic(const Duration(seconds: 2 * risTimeout), (_) => _whoisUpdate());
      });
      logger?.p("action 'Whois': whoKeys=$whoKeys");
    case 'h':
    case 'H': keyHelp(); showStat(host, stat, _hops);
      logger?.p("action 'help'");
    case ' ':
    case 'P': pause = !pause; addnote = pause ? ': output in pause' : null;
      logger?.p("action 'pause': pause=$pause");
    case 'R':
      logger?.p("action 'reset'");
      addnote = ': resetting...'; _postclearNote = true;
      _resetStats();
    case 'x':
    case 'Q':
      logger?.p("action 'quit'");
      addnote = ': quitting...';
      for (int i = 0; i < maxTTL; i++) { _stopPingAt(i, 'quit'); }
  }
}

Future<void> _waitWhoisReply(int i, int j) async {
  stat[i].whoislock.add(j);
  var addr = stat[i].info[j].addr;
  if (addr != null) {
    RIS? ris;
    try { ris = await risWhois(addr); }
    catch (e) { logger?.p('whois: $e'); }
    finally { stat[i].info[j] = (addr: addr, name: stat[i].info[j].name, whois: ris); }
  }
  stat[i].whoislock.remove(j);
}

Future<void> _whoisUpdate() async {
  if (whoKeys == null) return;
  int end = (hops < lastTTL) ? hops : lastTTL;
  List<Future<void>> list = [];
  for (int i = firstTTL - 1; i < end; i++) {
    for (int j = 0; j < stat[i].info.length; j++) {
      if (stat[i].whoislock.contains(j)) continue;
      if (stat[i].info[j].whois == null) list.add(_waitWhoisReply(i, j));
    }
  }
  await Future.wait(list);
}

Future<void> pingHops(String host) async {
  _clearPings();
  Timer? pingTimer, kbdTimer;
  if (displayMode) {
    pingTimer = Timer.periodic(const Duration(seconds: 1), (_) => showStat(host, stat, _hops));
    kbdTimer = Timer.periodic(const Duration(milliseconds: 100), (_) => _keyActions(host));
  }
  if (whoKeys != null) _whoisTimer = Timer.periodic(const Duration(seconds: 2 * risTimeout), (_) => _whoisUpdate());
  await _futuresInRange(host, firstTTL, lastTTL);
  logger?.p("ping '$host' is started (interval=${interval}sec cycles=${count ?? 'nolimit'})");
  while (_futures.whereNotNull().isNotEmpty) {
    logger?.p('waitlist of ${_futures.whereNotNull().length} pings');
    await Future.wait(_futures.whereNotNull());
    while (_futureslocked) { sleep(const Duration(milliseconds: 1)); }
  }
  logger?.p("ping '$host' is finished");
  _whoisTimer?.cancel();
  if (displayMode) {
    sleep(Duration(milliseconds: interval * 1000 ~/ 2));
    pingTimer?.cancel();
    kbdTimer?.cancel();
    showStat(host, stat, _hops);
    sleep(const Duration(milliseconds: 500)); // 0.5sec enough to spot last updates
  }
}

