
import 'dart:io' show Platform, exit;
import 'package:dart_ping/dart_ping.dart';
import 'package:sprintf/sprintf.dart';
import 'package:args/args.dart';

// default CLI args' values
const waitTimeout = 1; // in seconds
const dnsResolve = true;
const reportCycles = 10; // for report mode only

// misc internal constants
const maxTtl = 15;
const hostnameLen = 30;
final hopHeader = sprintf('%-*s\t%s\t%s\t%s', [hostnameLen, 'Host', 'Sent', 'Rcvd', 'Last']);

int hops = maxTtl;

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
//      print("reply $re on ttl=$ttl (ndx=$ndx)"); // TMP
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
//            print("prev=${stat[ndx].ts} curr=${parseTs(re.ts)}"); // TMP
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


Future <void> pingHops({required String host, int? count, int timeout = waitTimeout, bool dns = dnsResolve}) async {
  List<Future<void>> readers = [];
  for (int i = 0; i < maxTtl; i++) {
    int ttl = i + 1;
    stat[i].ping = Ping(host, ttl: ttl, timing: true, count: count, timeout: timeout, dns: dns);
    var p = stat[i].ping;
    if (p != null) readers.add(readEvents(ttl, p.stream));
  }
  await Future.wait(readers).then((_) => {/*print("finish")*/});
}


usage(String name, help, int indent) {
  final br = sprintf('\n%*s', [indent, '']);
  print("Usage: $name [-hn] [-c cycles] [-w timeout] HOST ...$br${help.replaceAll('\n', br)}");
  exit(-1);
}


main(List<String> args) async {
  final myname = (Platform.executable == 'dart') ? 'dmtr' : Platform.executable;
  late String host;
  int? count;
  int timeout = waitTimeout;
  bool? dns;
  bool? report;

  // Parse arguments
  final parser = ArgParser();
  parser.addOption('count', abbr: 'c', help: 'Run N cycles of pinging a target (default: no limit)', valueHelp: 'cycles');
  parser.addFlag('numeric', abbr: 'n', help: 'Disable DNS resolve of hops, i.e. numeric output', negatable: false);
  parser.addFlag('report',  abbr: 'r', help: 'Run $reportCycles and print stats at exit', negatable: false);
  parser.addOption('wait',  abbr: 'w', help: 'Wait N seconds for a response (default: 1)', valueHelp: 'seconds');
  parser.addFlag('help',    abbr: 'h', help: 'Show help', negatable: false);
  try {
    final parsed = parser.parse(args);
    if (parsed['count'] != null) {
      count = int.parse(parsed['count']);
      if (count <= 0) throw FormatException("Number($count) of cycles must be great than 0");
    }
    if (parsed['wait'] != null) {
      timeout = int.parse(parsed['wait']);
      if (timeout <= 0) throw FormatException("Timeout($timeout) in seconds must be great than 0");
    }
    if (parsed['numeric'] != null) dns = parsed['numeric'];
    if (parsed['report'] != null) {
      report = parsed['report'];
      count = reportCycles;
    }
    if (parsed['help'] ?? false) usage(myname, parser.usage, 4);
    if (parsed.rest.isEmpty) throw FormatException("Target HOST is not set");
    host = parsed.rest[0]; // TODO: loop all of them
  } catch(e) {
    print("$myname: ${e.toString().split('.')[0]}\n");
    usage(myname, parser.usage, 4);
  }
//print("host=$host count=$count timeout=$timeout dns=$dns report=$report"); // TMP

  // Run main loop
  await pingHops(host: host, count: count, timeout: timeout, dns: dns ?? dnsResolve);

  // Print report if necessary
  if (report ?? false) {
    print(sprintf('    %s', [hopHeader]));
    for (int i = 0; i < hops; i++) {
      print(sprintf('%2d. %s', [i + 1, stat[i]]));
    }
  }

}

