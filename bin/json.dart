
import 'common.dart';
import 'params.dart';
import 'aux.dart';
import 'riswhois.dart' show info2map;

Map<String, dynamic> getMappedHops(List<Hop> stat, int hops, String host) {
  List<Map<String, dynamic>> all = [];
  if (gotdata) {
    int end = (hops < lastTTL) ? hops : lastTTL;
    for (int i = firstTTL - 1; i < end; i++) { all.add(_hop2map(stat[i], i + 1)); }
  }
  try { _trimEmptyEntries(all); } catch (_) {} // trim last empty entries
  var map = { 'target': host, 'stats': all };
  if (all.isEmpty) map['info'] = msgs.nodata;
  if (fails.isNotEmpty) { map['fail'] = fails.getUnique(hops); fails.clearAll(); }
  return map;
}

const _extra = 'extra';

Map<String, dynamic> _hop2map(Hop h, int ttl) {
  var tm = {
    'last': _todbl(h.msec), 'best': _todbl(h.best), 'wrst': _todbl(h.wrst),
    'avg': _todbl(h.avg), 'jttr': _todbl(h.jttr)
  };
  tm.removeWhere((k, v) => (v is String) ? v.isEmpty : false);
  List<Map<String, dynamic>> hostinfo = [];
  for (var i in h.info) {
    Map<String, dynamic> m = {};
    if (i.addr != null) m['addr'] = i.addr;
    if (i.name != null) m['name'] = i.name;
    var w = i.whois;
    if (w != null) m.addAll(info2map(w));
    if (m.isNotEmpty) hostinfo.add(m);
  }
  //
  var map = {'ttl': ttl, 'sent': h.data.sent, 'rcvd': h.data.rcvd, 'loss': h.loss};
  if (hostinfo.isNotEmpty) map['host'] = hostinfo;
  if (tm.isNotEmpty) map.addAll({'timeunit': 'millisecond', 'timing': tm});
  List<String> ext = [];
  if (!h.reachable) ext.add(msgs.unreach.trim());
  var mesg = h.wrong; if (mesg != null) ext.add(mesg);
  if (ext.isNotEmpty) map[_extra] = ext.join(', ');
  return map;
}

dynamic _todbl(var v) { try { return double.parse(v); } catch (_) { return '$v'; } }

void _trimEmptyEntries(List<Map<String, dynamic>> list) {
  var l = list.length; int n = 0;
  for (int i = l - 1; i > 0; i--, n++) {
    if ((list[i]['host'] != null) || (list[i - 1]['host'] != null)) break; }
  if (n > 0) {
    list.removeRange(l - n, l); l = list.length - 1;
    list[l][_extra] = msgs.nopong.trim();
  }
}

