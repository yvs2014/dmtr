
import 'package:sprintf/sprintf.dart' show sprintf;
import 'common.dart';
import 'params.dart';
import 'aux.dart';

void printReport(List<Hop> stat, int hops) {
  if (hops > 0) {
    print(sprintf('%*s%-*s %s', [lindent, '', dnsEnable ? maxHostname : maxHostaddr, hostTitle, statTitle]));
    if (!gotdata) return;
    int end = (hops < lastTTL) ? hops : lastTTL;
    for (int i = firstTTL - 1; i < end; i++) {
      String no = sprintf('%2d. ', [i + 1]);
      print(sprintf('%*s%s', [lindent, no, (stat[i].data.sent > 0) ? stat[i] : '']));
      for (int j = 1; j < stat[i].addr.length; j++) { print(sprintf('%*s%s', [lindent, '', stat[i].lpart(j)])); }
      if (stat[i].unreach) print(unreachMesg.trim());
      var mesg = stat[i].wrong;
      if (mesg != null) print(wrongMesg(mesg));
    }
  }
}

