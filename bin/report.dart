
import 'package:sprintf/sprintf.dart' show sprintf;
import 'common.dart';
import 'params.dart';
import 'aux.dart';

void printReport(List<Hop> stat, int hops) {
  if (hops > 0) {
    print(sprintf('%*s%-*s %s', [lindent, '', hostPartLen, hostTitle, statTitle]));
    if (!gotdata) return;
    List<PongData> pongs = [];
    bool pong = true;
    int end = (hops < lastTTL) ? hops : lastTTL;
    for (int i = firstTTL - 1; i < end; i++) {
      List<String> data = [];
      pong = stat[i].info.isNotEmpty;
      String no = sprintf('%2d. ', [i + 1]);
      data.add(sprintf('%*s%s', [lindent, no, (stat[i].data.sent > 0) ? stat[i] : '']));
      for (int j = 1; j < stat[i].info.length; j++) {
        data.add(sprintf('%*s%s', [lindent, '', stat[i].lpart(j)])); }
      if (!stat[i].reachable) data.add(msgs.unreach.trim());
      var mesg = stat[i].wrong;
      if (mesg != null) data.add(msgs.wrong(mesg));
      pongs.add((pong: pong, data: data));
    }
    if (!pong) try { trimTail(pongs, trim: true); } catch (_) {}
    for (var p in pongs) { for (var s in p.data) { print(s); }}
  }
}

