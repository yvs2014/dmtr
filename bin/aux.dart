
import 'package:sprintf/sprintf.dart' show sprintf;
import 'riswhois.dart' show withWhoTitle;
import 'params.dart';

// title
String? _title;
get title => _title;
set title(host) { _title = ['$myname-$version', optstr, host].where((a) => (a != null) && a.isNotEmpty).join(' '); }
// left(host)
const hopTitle = 'Hops';
const lindent = 4; // lpart's indent
get hostTitle => withWhoTitle(hopTitle);
// right(stat)
const _commonFmt = '%-4s';
const Map<String,String> _notcommonFmt = {'s': '%-5s', ' ': '%s'};
get statTitle => rpartFn({'l':'Loss', 's':'Sent', 'm':'Last', 'b':'Best', 'w':'Wrst', ' ': '', 'a':'Avrg', 'j':'Jttr'});

// extra messaging
final msgs = (
  nodata: 'no data',
  nopong:  sprintf('%*s%s', [lindent, '', 'No response']),
  unreach: sprintf('%*s%s', [lindent, '', 'Destination is unreachable']),
  wrong: (String cause) => sprintf('%*s%s', [lindent, '', 'Got wrong data: $cause']),
);

// pretty print
const _floatUpto = 10;
const _twoDigitsUpto = 0.1;
String prfmt(double v) => sprintf('%.*f', [((v > 0) && (v < _floatUpto)) ? ((v < _twoDigitsUpto) ? 2 : 1) : 0, v]);

// aggregate unique error messages per hop
final fails = Fails(maxTTL);
class Fails {
  final int max;
  late final List<List<String>> errs;
  Fails(int len, {this.max = 10}) { errs = List<List<String>>.filled(len, []); }
  void add(int ndx, String? mesg) {
    if ((ndx >= errs.length) || (mesg == null)) return;
    if (!errs[ndx].contains(mesg)) errs[ndx].add(mesg);
    if (errs[ndx].length > max) errs[ndx].removeAt(0); // no more 'max' errors per hop
  }
  void clear(int ndx) { if ((ndx < errs.length) && errs[ndx].isNotEmpty) errs[ndx] = []; }
  void clearAll() { for (int i = 0; i < errs.length; i++) { errs[i] = []; }}
  bool get isNotEmpty { for (var l in errs) { if (l.isNotEmpty) return true; } return false; }
  List<String> getUnique(int first) {
    Set<String> u = {}; int min = (first < errs.length) ? first : errs.length;
    for (int i = 0; i < min; i++) { u.addAll(errs[i]); }
    return u.toList();
  }
}

// key hints in ncurses' mode
typedef KeyHint = ({String key, int b, String hint}); // 'b' is index of bold character
final List<KeyHint> keyhints = [
  (key: 'count',   b: 0, hint: 'number of cycles to ping'),
  (key: 'fields',  b: 0, hint: 'stat fields to display, chars stand for: $statKeysDesc'),
  (key: 'dns',     b: 0, hint: 'toggle hostname/ipaddr show (note: on linux it works only in non-numeric mode)'),
  (key: 'ival',    b: 0, hint: 'interval between pings in seconds'),
  (key: 'payload', b: 0, hint: 'payload pattern'),
  (key: 'qos',     b: 0, hint: 'set QoS bits'),
  (key: 'size',    b: 0, hint: 'payload size'),
  (key: 'ttl',     b: 0, hint: 'set TTL range in min,max format'),
  (key: 'who',     b: 0, hint: "toggle whois info diaplying (note: press 'W' to set whois-fields in [$whoPatt]+ format)"),
  (key: 'Reset',   b: 0, hint: 'reset stats'),
  (key: 'Pause',   b: 0, hint: 'pause/resume'),
  (key: 'Quit',    b: 0, hint: "stop and exit, 'x' is aliased to 'Q'"),
  (key: 'Help',    b: 0, hint: 'this help'),
];
final int hkMaxLen = keyhints.reduce((a, b) => ((a.key.length > b.key.length) ? a : b)).key.length;
final int hkTotal = keyhints.reduce((a, b) => (key: '${a.key} ${b.key}', b:0, hint:'')).key.length;

//
// rest: aux functions

typedef PongData = ({bool pong, List<String> data});
void trimTail(List<PongData> list, { bool trim = false }) {
  var l = list.length;
  int n = 0; for (int i = l - 1; i > 0; i--, n++) { if (list[i].pong || list[i - 1].pong) break; }
  if (n > 0) {
    list.removeRange(l - n, l); l = list.length - 1;
    var mesg = msgs.nopong; if (trim) mesg = mesg.trim();
    list[l] = (pong: false, data: [mesg]);
  }
}

String rpartFn(Map<String, String> m) {
  List<String> fmts = [], args = [];
  for (var c in statKeysList) {
    var mc = m[c];
    if (mc == null) continue;
    fmts.add(_notcommonFmt[c] ?? _commonFmt);
    args.add(mc);
  }
  return sprintf(fmts.join(' '), args);
}

(String?, String?) parseCycles(String s) {
  try {
    int c = int.parse(s);
    if (c <= 0) return ('Number($c) of cycles must be great than 0', null);
    if (c != count) { count = c; paramsChanged = true; }
  } catch (e) { return ('Cycles: $e', null); }
  return (null, '$count');
}

final RegExp _statkeys = RegExp(r'^[' + statKeysDef + r']+$');
(String?, String?) parseStatKeys(String s) {
  try {
    if (!_statkeys.hasMatch(s)) return ("stat fields '$s' must match '[$statKeysDef]+' pattern", null);
    if (s != statKeys) {
      statKeys = String.fromCharCodes(s.codeUnits.toSet().toList());
      statKeysList = statKeys.split('');
      paramsChanged = true; }
  } catch (e) { return ('stat fields: $e', null); }
  return (null, statKeys);
}

(String?, String?) parseIval(String s) {
  try {
    int i = int.parse(s);
    if (i <= 0) return ('Interval($i) in seconds must be great than 0', null);
    if (i != interval) { interval = i; paramsChanged = true; }
  } catch (e) { return ('Interval: $e', null); }
  return (null, '$interval');
}

final RegExp _hex = RegExp(r'^([\da-fA-F]{1,32})$');
(String?, String?) parsePayload(String s) {
  try {
    if (!_hex.hasMatch(s)) return ('Payload pattern($s) must be in hex format upto 16bytes, regexp: [0-9a-fA-F]{1,32}', null);
    if (s != payload) { payload = s; paramsChanged = true; }
  } catch (e) { return ('Payload pattern: $e', null); }
  return (null, '$payload');
}

(String?, String?) parseQoS(String s) {
  try {
    int q = int.parse(s);
    if ((q < 0) || (q > 255)) return ('QoS/ToS bits ($q) must be in range 0..255', null);
    if (q != qos) { qos = q; paramsChanged = true; }
  } catch (e) { return ('QoS/ToS: $e', null); }
  return (null, '$qos');
}

(String?, String?) parseSize(String s) {
  try {
    int sz = int.parse(s);
    if ((sz < psize_.min) || (sz > psize_.max)) return ('Payload size($sz) must be in range ${psize_.min}..${psize_.max}', null);
    if (sz != psize) { psize = sz; paramsChanged = true; }
  } catch (e) { return ('Payload size: $e', null); }
  return (null, '$psize');
}

(String?, String?) parseTTL(String s) {
  try {
    var mm = s.split(',');
    if (mm.isNotEmpty) {
      int ttl0 = firstTTL, ttl1 = lastTTL;
      if (mm[0].isNotEmpty) {
        ttl0 = int.parse(mm[0]);
        if ((ttl0 < 1) || (ttl0 > maxTTL)) return ('Min TTL ($ttl0) is out of range 1..$maxTTL', null);
      }
      if ((mm.length > 1) && mm[1].isNotEmpty) {
        ttl1 = int.parse(mm[1]);
        if ((ttl1 < ttl0) || (ttl1 > maxTTL)) return ('Max TTL ($ttl1) is out of range $ttl0..$maxTTL', null);
      }
      if (ttl0 != firstTTL) { firstTTL = ttl0; paramsChanged = true; }
      if (ttl1 != lastTTL) { lastTTL = ttl1; paramsChanged = true; }
    }
  } catch (e) { return ('TTL: $e', null); }
  return (null, '$firstTTL..$lastTTL');
}

final RegExp _riskeys = RegExp(r'^[' + whoPatt + r']+$');
(String?, String?) parseWhoKeys(String s) {
  try {
    // special case1 '' or '-' to unset
    if ((s == '') || (s == '-')) { if (whoKeys != null) { whoKeys = null; paramsChanged = true; }}
    else {
      if (s == '.') s = whoKeysDef; // special case2 '.' to set default
      if (!_riskeys.hasMatch(s)) return ("whois keys '$s' must match '[$whoPatt]+' pattern\n  note: use '' or '-' to unset, '.' to set default", null);
      if (s != whoKeys) {
        whoKeys = String.fromCharCodes(s.codeUnits.toSet().toList());
        whoKeysList = whoKeys?.split('') ?? [];
        paramsChanged = true;
      }
    }
  } catch (e) { return ('whois keys: $e', null); }
  return (null, whoKeys);
}

