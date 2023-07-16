
import 'dart:io' show exit, sleep;
import 'dart:convert' show JsonEncoder;
import 'package:sprintf/sprintf.dart';
import 'package:args/args.dart' show ArgParser;
import 'sysping.dart' show probeSysping;

import 'common.dart';
import 'pinger.dart';
import 'report.dart';
import 'json.dart';
import 'dcurses.dart';

void usage(String name, help, int indent) {
  final br = sprintf('\n%*s', [indent, '']);
  print("Usage: $name [-hn] [-c cycles] [-t [minTTL][,maxTTL]] [-w timeout] HOST ...$br${help.replaceAll('\n', br)}");
  exit(-1);
}


main(List<String> args) async {
  { final failed = await probeSysping(); if (failed != null) { print(failed); exit(-1); }}
  List<String> targets = [];

  // Parse arguments
  final parser = ArgParser();
  parser.addOption('count', abbr: 'c', help: 'Run N cycles of pinging a target (default: no limit)', valueHelp: 'cycles');
  parser.addFlag('numeric', abbr: 'n', help: 'Disable DNS resolve of hops, i.e. numeric output', negatable: false);
  parser.addFlag('report',  abbr: 'r', help: 'Run N cycles (default $reportCycles) and print plain report at exit', negatable: false);
  parser.addFlag('json',    abbr: 'j', help: 'Run N cycles (default $reportCycles) and print stats in JSON format', negatable: false);
  parser.addOption('ttl',   abbr: 't', help: 'TTL range to ping, it can be also min or max only (default $firstTtl,$endTtl)', valueHelp: 'min,max');
  parser.addOption('wait',  abbr: 'w', help: 'Wait N seconds for a response (default $timeout)', valueHelp: 'seconds');
  parser.addFlag('help',    abbr: 'h', help: 'Show help', negatable: false);
  try {
    final parsed = parser.parse(args);
    if (parsed['count'] != null) {
      count = int.parse(parsed['count']);
      if ((count ?? 1) <= 0) throw FormatException('Number($count) of cycles must be great than 0');
    }
    if (parsed['ttl'] != null) {
      var mm = parsed['ttl'].split(',');
      if (mm.isNotEmpty) {
        if (mm[0].isNotEmpty) {
          firstTtl = int.parse(mm[0]);
          if ((firstTtl <= 0) || (firstTtl >= maxTtl)) {
            throw FormatException('Min TTL ($firstTtl) is out of range 1-$maxTtl'); }
        }
        if ((mm.length > 1) && mm[1].isNotEmpty) {
          endTtl = int.parse(mm[1]);
          if ((endTtl < firstTtl) || (endTtl >= maxTtl)) {
            throw FormatException('Max TTL ($endTtl) is out of range $firstTtl-$maxTtl'); }
        }
      }
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
    if (parsed['json'] != null) {
      jsonEnable = parsed['json'];
      if (jsonEnable) count ??= reportCycles;
    }
    if (parsed['help'] ?? false) usage(myname, parser.usage, 4);
    if (parsed.rest.isEmpty) throw FormatException("Target HOST is not set");
    optstr = args.where((a) => !parsed.rest.contains(a)).join(' ');
    targets = parsed.rest;
  } catch(e) {
    print("$myname: ${e.toString().split('.')[0]}\n");
    usage(myname, parser.usage, 4);
  }

  displayMode = !(reportEnable || jsonEnable);
  if (displayMode && !openDisplay()) return -1;
  List json = [];
  for (var i = 0; i < targets.length; i++) { // note: one by one, not async
    fail = null;
    setTitle(targets[i]);
    await pingHops(targets[i]); // Run main loop
    if (displayMode && (fail != null)) { addnote = '($fail)'; printTitle(0, 0, up: true);
      sleep(Duration(seconds: 3)); addnote = null;}
    if (reportEnable) { // Print plain report
      if (i != 0) print('');
      String now = '${DateTime.now()}';
      now = now.substring(0, now.indexOf('.'));
      if (fail != null) { print('[$now] $fail'); }
      else { print("[$now] $title"); printReport(stat, hops); }
    }
    if (jsonEnable) json.add(getMappedHops(stat, hops, targets[i])); // Add mapped stats for a target
  }
  if (displayMode) closeDisplay();
  if (jsonEnable) { // Print report in JSON format
    var encoder = JsonEncoder.withIndent('  ');
    print(encoder.convert(json));
  }
}

