
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
  var map = { 'target': host, 'stats': all };
  if (all.isEmpty) map['info'] = nodataMesg;
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
  var all = {'ttl': ttl, 'sent': h.data.sent, 'rcvd': h.data.rcvd, 'loss': h.loss};
  if (hostinfo.isNotEmpty) all['host'] = hostinfo;
  if (tm.isNotEmpty) all.addAll({'timeunit': 'millisecond', 'timing': tm});
  if (!h.reachable) all[_extra] = unreachMesg;
  var mesg = h.wrong;
  if (mesg != null) {
    var extraMesg = wrongMesg(mesg).trim();
    all[_extra] = all.containsKey(_extra) ? '${all[_extra]}, $extraMesg' : extraMesg;
  }
  return all;
}

dynamic _todbl(var v) { try { return double.parse(v); } catch (_) { return '$v'; } }

