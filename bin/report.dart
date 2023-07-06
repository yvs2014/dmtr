
import 'package:sprintf/sprintf.dart';
import 'common.dart';

const reportCycles = 10; // for upper layers
final hopHeader = sprintf('%-*s\t%s\t%s\t%s', [hostnameLen, 'Host', 'Sent', 'Rcvd', 'Last']);

printReport({int indent = 4, String? header, required List<Hop> stat, required int hops, String? target, bool last = false}) {
  if (hops > 0) {
    if (target != null) print('Ping $target');
    print(sprintf('%*s%s', [indent, '', header ?? hopHeader]));
    for (int i = 0; i < hops; i++) {
      String no = sprintf('%2d. ', [i + 1]);
      print(sprintf('%*s%s', [indent, no, (stat[i].sent > 0) ? stat[i] : '']));
    }
  }
  if (!last) print('');
}

