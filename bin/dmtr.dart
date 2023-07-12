
import 'dart:io' show exit;
import 'package:sprintf/sprintf.dart';
import 'package:args/args.dart' show ArgParser;

import 'common.dart';
import 'pinger.dart';
import 'report.dart';
import 'dcurses.dart';

usage(String name, help, int indent) {
  final br = sprintf('\n%*s', [indent, '']);
  print("Usage: $name [-hn] [-c cycles] [-w timeout] HOST ...$br${help.replaceAll('\n', br)}");
  exit(-1);
}


main(List<String> args) async {
  List<String> targets = [];

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
      if ((count ?? 1) <= 0) throw FormatException("Number($count) of cycles must be great than 0");
    }
    if (parsed['wait'] != null) {
      timeout = int.parse(parsed['wait']);
      if (timeout <= 0) throw FormatException("Timeout($timeout) in seconds must be great than 0");
    }
    if (parsed['numeric'] != null) { numeric = parsed['numeric']; dnsEnable = !numeric; }
    if (parsed['report'] != null) {
      reportEnable = parsed['report'];
      if (reportEnable) count ??= reportCycles;
    }
    if (parsed['help'] ?? false) usage(myname, parser.usage, 4);
    if (parsed.rest.isEmpty) throw FormatException("Target HOST is not set");
    optstr = args.where((a) => !parsed.rest.contains(a)).join(' ');
    targets = parsed.rest;
  } catch(e) {
    print("$myname: ${e.toString().split('.')[0]}\n");
    usage(myname, parser.usage, 4);
  }

  if (!reportEnable && !openDisplay()) return -1;
  for (var i = 0; i < targets.length; i++) { // note: one by one, not async
    setTitle(targets[i]);
    await pingHops(targets[i]); // Run main loop
    if (reportEnable) { // Print report if necessary
      if (i != 0) print('');
      String now = '${DateTime.now()}';
      print("[${now.substring(0, now.indexOf('.'))}] $title");
      printReport(stat, hops);
    }
  }
  if (!reportEnable) closeDisplay();
}

