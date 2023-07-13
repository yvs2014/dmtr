
import 'package:sprintf/sprintf.dart' show sprintf;
import 'common.dart';

printReport(List<Hop> stat, int hops) {
  if (hops > 0) {
    print(sprintf('%*s%-*s %s', [lindent, '', dnsEnable ? maxHostname : maxHostaddr, hostTitle, statTitle]));
    for (int i = 0; i < hops; i++) {
      String no = sprintf('%2d. ', [i + 1]);
      print(sprintf('%*s%s', [lindent, no, (stat[i].data.sent > 0) ? stat[i] : '']));
      for (int j = 1; j < stat[i].addr.length; j++) { print(sprintf('%*s%s', [lindent, '', stat[i].lpart(j)])); }
    }
  }
}

