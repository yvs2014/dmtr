
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

const _floatUpto = 10;
const _twoDigitsUpto = 0.1;
String prfmt(double v) => sprintf('%.*f', [((v > 0) && (v < _floatUpto)) ? ((v < _twoDigitsUpto) ? 2 : 1) : 0, v]);

List<String?> fails = []; // message(s) if something went wrong (for example 'unknown host')
void addFail(String? m) { if ((m != null) && !fails.contains(m)) fails.add(m); }

typedef KeyHint = ({String key, String hint});
final List<KeyHint> keyhints = [
  (key: 'help',  hint: 'this help'),
  (key: 'dns',   hint: 'toggle hostname/ipaddr show (note: on linux it works only in non-numeric mode)'),
  (key: 'ttl',   hint: 'set ttl range in min,max format'),
//  (key: 'size',  hint: 'payload size'), /* not yet */
  (key: 'reset', hint: 'reset stats'), 
  (key: 'pause', hint: 'pause/resume'), 
  (key: 'quit',  hint: 'stop and exit'),
];
final int maxHKey = keyhints.reduce((a, b) { return a.key.length > b.key.length ? a : b; }).key.length;

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
  } catch (e) { return ('$e', null); }
  return (null, '$firstTTL..$lastTTL');
}

(String?, String?) parsePsize(String s) {
  try {
    int sz = int.parse(s);
    if ((sz < psize_.min) || (sz > psize_.max)) return ('Payload size($sz) must be in range ${psize_.min}..${psize_.max}', null);
    psize = sz;
  } catch (e) { return ('$e', null); }
  return (null, '$psize');
}

