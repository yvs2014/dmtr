import 'dart:io';
import 'package:dart_ping/dart_ping.dart';

int maxTtl = 30;
int timeout = 1; // 1sec

class Hop {
  int snt = 0;
  int rcvd = 0;
  int last = 0;
  String? addr;
  String? name;
//  Hop();
}

List<Hop> stat = List<Hop>.generate(maxTtl, (_) => Hop());

Future<bool> cyclePing() async {
  bool goal = false;
  for (int i = 0; i < maxTtl; i++) {
    int ttl = i + 1;
    final timer = Stopwatch()..start(); // for discarded replies
    var ping = Ping('google.com', timeout: timeout, count: 1, dns: true, ttl: ttl);
    stat[i].snt += 1;
    await for (final event in ping.stream) { // loop just in case for count>1
      timer.stop();
      var re = event.response;
      if (re != null) {
        if (re.time != null) {
          if (maxTtl > ttl) maxTtl = ttl; // stop pings at this ttl
          if (!goal) goal = true;
          stat[i].rcvd++;
          stat[i].last = re.time?.inMilliseconds ?? 0;
        } else {
          stat[i].last = timer.elapsedMilliseconds;
        }
        if (re.ip != null) stat[i].addr = re.ip;
        if (re.name != null) stat[i].name = re.name;
      }
    }
    if (timer.isRunning) timer.stop();
    if (goal) break;
  }
  return goal;
}

main() async {
  int count = 10;
  for (int i = 0; i < count; i++) {
//    print("tm: ${DateTime.now().millisecondsSinceEpoch}");
    final timer = Stopwatch()..start();
    bool re = await cyclePing();
    timer.stop();
    print('cycle=${i + 1} maxTtl=$maxTtl: reached=$re duration=${timer.elapsedMilliseconds}'); 
    if (!re) maxTtl++;
    int spareTime = timeout * 1000 - timer.elapsedMilliseconds;
    if (spareTime > 0) sleep(Duration(milliseconds: spareTime));
  }
  print("Hop#\tSnt\tRcvd\tLast[msec]");
  for (int i = 0; i < maxTtl; i++) {
    print("$i\t${stat[i].snt}\t${stat[i].rcvd}\t${stat[i].last}");
  }
}

