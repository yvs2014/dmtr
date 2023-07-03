
import 'package:sprintf/sprintf.dart';
import 'package:dart_ping/dart_ping.dart';

const maxTtl = 15;
const hostnameLen = 30;
final hopHeader = sprintf('%-*s\t%s\t%s\t%s', [hostnameLen, 'Host', 'Sent', 'Rcvd', 'Last[msec]']);

int hops = maxTtl;
int timeout = 1; // 1sec

typedef TsUsec = ({int sec, int usec}); // timestamp: sec, usec

class Hop {
  int sent = 0;
  int rcvd = 0;
  int last = 0; // in usec
  String? addr;
  String? name;
  //
  Ping? ping;
  int disc = -1; // to avoid dups at calculation of 'sent'
  TsUsec? ts;    // timestamp of timeouted response
  @override
  String toString() {
    final hop = (name ?? addr) ?? '';
    String l = (last > 0) ? sprintf("%.1f", [last / 1000]) : '-';
    return sprintf('%-*s\t%d\t%d\t%s', [hostnameLen, hop, sent, rcvd, l]);
  }
}

List<Hop> stat = List<Hop>.generate(maxTtl, (_) => Hop());

TsUsec parseTs(String s) {
  var a = s.split('.');
  int sec = 0, usec = 0;
  if (a.length == 2) { sec = int.parse(a[0]); usec = int.parse(a[1]); }
  if (a.length == 1) sec = int.parse(a[0]);
  return (sec: sec, usec: usec);
}

void setHopINSR(int ndx, PingResponse re) {
   if (re.ip != null) stat[ndx].addr = re.ip;
   if (re.name != null) stat[ndx].name = re.name;
   stat[ndx].sent++;
   stat[ndx].rcvd++;
   if (re.seq != null) stat[ndx].disc = re.seq!;
}

Future <void> readEvents(int ttl, var stream) async {
  await for (final ev in stream) {
    var re = ev.response;
    if (re != null) {
      int ndx = ttl - 1;
//      print("reply $re on ttl=$ttl (ndx=$ndx)");
      switch (re?.status) {
        case ReStatus.success:
          if ((re.ttl != null) && (hops > ttl)) {
            hops = ttl; // stop pings at this ttl
            for (int i = hops; i < maxTtl; i++) { stat[i].ping?.stop(); }
          }
          if (re.time != null) stat[ndx].last = re.time?.inMicroseconds ?? 0;
          setHopINSR(ndx, re);
        case ReStatus.discard:
          setHopINSR(ndx, re);
          if ((re.ts != null) && (stat[ndx].ts != null)) {
//            print("prev=${stat[ndx].ts} curr=${parseTs(re.ts)}");
            TsUsec tu = parseTs(re.ts);
            stat[ndx].last = ((tu.sec - stat[ndx].ts!.sec) * 1000000 + (tu.usec - stat[ndx].ts!.usec)).toInt();
          }
        case ReStatus.timeout:
          if (stat[ndx].disc != re.seq) stat[ndx].sent++;
          stat[ndx].ts = (re.ts != null) ? parseTs(re.ts) : null; // keep it for possible future discard
      }
    }
  }
}


Future <void> pingHops(String host, int count) async {
  List<Future<void>> readers = [];
  for (int i = 0; i < maxTtl; i++) {
    int ttl = i + 1;
    stat[i].ping = Ping(host, count: count, ttl: ttl, timeout: timeout, timing: true, dns: true);
    var p = stat[i].ping;
    if (p != null) readers.add(readEvents(ttl, p.stream));
  }
  await Future.wait(readers).then((_) => {/*print("finish")*/});
}


main() async {
  var count = 5;
  var host = 'google.com';
  await pingHops(host, count);
  print(sprintf('    %s', [hopHeader]));
  for (int i = 0; i < hops; i++) {
    print(sprintf('%2d. %s', [i + 1, stat[i]]));
  }
}

