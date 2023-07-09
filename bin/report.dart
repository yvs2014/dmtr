
import 'package:sprintf/sprintf.dart' show sprintf;
import 'common.dart';

const reportCycles = 10; // for upper layers

printReport({required List<Hop> stat, required int hops, String? target, bool last = false, int indent = 4}) {
  if (hops > 0) {
    if (target != null) print('Ping $target');
    print(sprintf('%*s%-*s %s', [indent, '', hostnameLen, hostTitle, statTitle]));
    for (int i = 0; i < hops; i++) {
      String no = sprintf('%2d. ', [i + 1]);
      print(sprintf('%*s%s', [indent, no, (stat[i].data.sent > 0) ? stat[i] : '']));
    }
  }
  if (!last) print('');
}

