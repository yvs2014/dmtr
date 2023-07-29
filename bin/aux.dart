
import 'package:sprintf/sprintf.dart' show sprintf;
import 'params.dart';

const statfmt = '%-4s %-5s %-4s %-4s %-4s  %-4s %-4s';
final statMax = sprintf(statfmt, List<String>.filled(7, '')).length;

// left(host) and right(stat) parts of stats header
const hostTitle = 'Hops';
final statTitle = sprintf(statfmt, ['Loss', 'Sent', 'Last', 'Best', 'Wrst', 'Avrg', 'Jttr']);
const lindent = 4; // lpart's indent
String? _title;
get title => _title;
set title(host) {
  _title = ['$myname-$version', optstr, host].where((a) => (a != null) && a.isNotEmpty).join(' ');
}

// extra messaging
const _unreachMesg = 'Destination is unreachable';
get unreachMesg => sprintf('%*s%s', [lindent, '', _unreachMesg]);
const _wrongMesg = 'Got wrong data: ';
String wrongMesg(String cause) => sprintf('%*s%s%s', [lindent, '', _wrongMesg, cause]);

// pretty print
const _floatUpto = 10;
const _twoDigitsUpto = 0.1;
String prfmt(double v) => sprintf('%.*f', [((v > 0) && (v < _floatUpto)) ? ((v < _twoDigitsUpto) ? 2 : 1) : 0, v]);

// messages if something went wrong (for example 'unknown host')
List<String?> fails = [];
void addFail(String? m) { if ((m != null) && !fails.contains(m)) fails.add(m); }

// key hints in ncurses' mode
typedef KeyHint = ({String key, int b, String hint}); // 'b' is index of bold character
final List<KeyHint> keyhints = [
  (key: 'help',    b: 0, hint: 'this help'),
  (key: 'dns',     b: 0, hint: 'toggle hostname/ipaddr show (note: on linux it works only in non-numeric mode)'),
  (key: 'count',   b: 0, hint: 'number of cycles to ping'),
  (key: 'ttl',     b: 0, hint: 'set TTL range in min,max format'),
  (key: 'qos',     b: 1, hint: 'set QoS bits'),
  (key: 'size',    b: 0, hint: 'payload size'),
  (key: 'payload', b: 3, hint: 'payload pattern'),
  (key: 'reset',   b: 0, hint: 'reset stats'),
  (key: 'pause',   b: 0, hint: 'pause/resume'),
  (key: 'quit',    b: 0, hint: 'stop and exit'),
];
final int maxHKey = keyhints.reduce((a, b) { return a.key.length > b.key.length ? a : b; }).key.length;

// rest: aux functions
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

(String?, String?) parsePsize(String s) {
  try {
    int sz = int.parse(s);
    if ((sz < psize_.min) || (sz > psize_.max)) return ('Payload size($sz) must be in range ${psize_.min}..${psize_.max}', null);
    if (sz != psize) { psize = sz; paramsChanged = true; }
  } catch (e) { return ('Payload size: $e', null); }
  return (null, '$psize');
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

(String?, String?) parseCycles(String s) {
  try {
    int c = int.parse(s);
    if (c <= 0) return ('Number($c) of cycles must be great than 0', null);
    if (c != count) { count = c; paramsChanged = true; }
  } catch (e) { return ('Cycles: $e', null); }
  return (null, '$count');
}

