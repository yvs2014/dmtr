
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
  (key: 'help',  b: 0, hint: 'this help'),
  (key: 'dns',   b: 0, hint: 'toggle hostname/ipaddr show (note: on linux it works only in non-numeric mode)'),
  (key: 'ttl',   b: 0, hint: 'set TTL range in min,max format'),
  (key: 'qos',   b: 1, hint: 'set QoS bits'),
  (key: 'size',  b: 0, hint: 'payload size'),
  (key: 'reset', b: 0, hint: 'reset stats'),
  (key: 'pause', b: 0, hint: 'pause/resume'),
  (key: 'quit',  b: 0, hint: 'stop and exit'),
];
final int maxHKey = keyhints.reduce((a, b) { return a.key.length > b.key.length ? a : b; }).key.length;

// rest: aux functions
(String?, String?) parseTTL(String s) {
  try {
    var mm = s.split(',');
    if (mm.isNotEmpty) {
      if (mm[0].isNotEmpty) {
        int ttl = int.parse(mm[0]);
        if ((ttl < 1) || (ttl > maxTTL)) return ('Min TTL ($ttl) is out of range 1..$maxTTL', null);
        firstTTL = ttl;
      }
      if ((mm.length > 1) && mm[1].isNotEmpty) {
        int ttl = int.parse(mm[1]);
        if ((ttl < firstTTL) || (ttl > maxTTL)) return ('Max TTL ($ttl) is out of range $firstTTL..$maxTTL', null);
        lastTTL = ttl;
      }
    }
  } catch (e) { return ('TTL: $e', null); }
  return (null, '$firstTTL..$lastTTL');
}

(String?, String?) parsePsize(String s) {
  try {
    int sz = int.parse(s);
    if ((sz < psize_.min) || (sz > psize_.max)) return ('Payload size($sz) must be in range ${psize_.min}..${psize_.max}', null);
    psize = sz;
  } catch (e) { return ('Payload size: $e', null); }
  return (null, '$psize');
}

(String?, String?) parseQoS(String s) {
  try {
    int q = int.parse(s);
    if ((q < 0) || (q > 255)) return ('QoS/ToS bits ($q) must be in range 0..255', null);
    qos = q;
  } catch (e) { return ('QoS/ToS: $e', null); }
  return (null, '$qos');
}

