
import 'common.dart';

Map<String, dynamic> getMappedHops(List<Hop> stat, int hops, String host) {
  List<Map<String, dynamic>> all = [];
  if (hops > 0) for (int i = 0; i < hops; i++) { all.add(_hop2map(stat[i], i + 1)); }
  return { 'target': host, 'stats': all };
}

Map<String, dynamic> _hop2map(Hop h, int ttl) {
  var tm = {
    'last': _todbl(h.msec), 'best': _todbl(h.best), 'wrst': _todbl(h.wrst),
    'avg': _todbl(h.avg), 'jttr': _todbl(h.jttr)
  };
  tm.removeWhere((k, v) => (v is String) ? v.isEmpty : false);
  var all = {
    'ttl': ttl, 'addr': h.addr, 'name': h.name,
    'sent': h.data.sent, 'rcvd': h.data.rcvd, 'loss': h.loss,
  };
  all.removeWhere((k, v) => (v is List) ? v.isEmpty : false);
  if (tm.isNotEmpty) all.addAll({'timeunit': 'millisecond', 'timing': tm});
  return all;
}

dynamic _todbl(var v) { try { return double.parse(v); } catch (_) { return '$v'; } }

