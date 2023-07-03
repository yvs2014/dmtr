import 'dart:io';
import 'package:intl/intl.dart';
import 'package:dart_ping/dart_ping.dart';

const maxTtl = 15;
final frtt = NumberFormat("###.0");

int hops = maxTtl;
int timeout = 1; // 1sec

class Hop {
  int snt = 0;
  int rcvd = 0;
  int last = 0; // in usec
  String? addr;
  String? name;
  Ping? ping;
//  Hop();
}

List<Hop> stat = List<Hop>.generate(maxTtl, (_) => Hop());

Future <void> pingHop(String host, int i, int count) async {
  int ttl = i + 1;
  stat[i].ping = Ping(host, count: count, ttl: ttl, timeout: timeout, timing: true, dns: true);
  var p = stat[i].ping;
  if (p != null) {
    await for (final ev in p.stream) {
      var re = ev.response;
      if (re != null) {
        print("reply $re on ttl=$ttl (ndx=$i)");
        if (re.ttl != null) { // use re.ttl as a marker of successful ping
          if (hops > ttl) {
            hops = ttl; // stop pings at this ttl
            for (int j = hops; j < maxTtl; j++) { stat[i].ping?.stop(); }
          }
        }
      }
    }
  }
}


main() async {
  var count = 5;
  var host = 'google.com';
  final timer = Stopwatch()..start();
  //
  for (int i = 0; i < maxTtl; i++) { // start all pings upto maxTtl
    pingHop(host, i, count);
  }
  sleep(Duration(seconds: 10));
  timer.stop();
  print("elapsed[msec]: ${timer.elapsedMilliseconds}");
  print("Hop#\tSnt\tRcvd\tLast[msec]");
  for (int i = 0; i < hops; i++) {
    print("$i\t${stat[i].snt}\t${stat[i].rcvd}\t${frtt.format(stat[i].last / 1000)}");
  }
}

