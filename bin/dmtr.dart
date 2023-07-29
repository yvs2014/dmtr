
import 'dart:io' show exit, pid;
import 'dart:convert' show JsonEncoder;
import 'package:sprintf/sprintf.dart';
import 'package:args/args.dart' show ArgParser;

import 'params.dart';
import 'aux.dart';
import 'pinger.dart';
import 'report.dart';
import 'json.dart';
import 'dcurses.dart';
import 'sysping.dart' show probeSysping;
import 'syslogger.dart' show probeSyslogger, Syslogger;

void usage(String name, help, int indent) {
  final br = sprintf('\n%*s', [indent, '']);
  print("Usage: $name [-nrj46h] [-c cycles] [-i interval] [-s size] [-t [minTTL][,maxTTL]] [-Q QoS] [--syslog] TARGET ...$br${help.replaceAll('\n', br)}");
  exit(-1);
}


main(List<String> args) async {
  { final failed = await probeSysping(); if (failed != null) { print(failed); exit(-1); }}
  List<String> targets = [];

  // Parse arguments
  final parser = ArgParser();
  parser.addOption('cycles',   abbr: 'c', help: 'Run <number> cycles per target (default nolimit)', valueHelp: 'number');
  parser.addOption('interval', abbr: 'i', help: 'Interval in seconds between pings (default $interval)', valueHelp: 'seconds');
  parser.addOption('size',     abbr: 's', help: 'Payload size (default ${psize_.def})', valueHelp: 'bytes');
  parser.addOption('ttl',      abbr: 't', help: 'TTL range to ping, it can be also min or max only (default $firstTTL,$lastTTL)', valueHelp: 'min,max');
  parser.addOption('qos',      abbr: 'Q', help: 'QoS/ToS byte to set (default is not set)', valueHelp: 'bits');
  parser.addFlag('numeric', abbr: 'n', help: 'Numeric output (i.e. disable DNS resolve)', negatable: false);
  parser.addFlag('report',  abbr: 'r', help: 'Print simple report at exit', negatable: false);
  parser.addFlag('json',    abbr: 'j', help: 'Print report in JSON format', negatable: false);
  parser.addFlag('ipv4',    abbr: '4', help: 'IPv4 only', negatable: false);
  parser.addFlag('ipv6',    abbr: '6', help: 'IPv6 only', negatable: false);
  parser.addFlag('help',    abbr: 'h', help: 'Show help', negatable: false);
  parser.addFlag('syslog',  help: 'Syslog for debug', negatable: false);
  try {
    final parsed = parser.parse(args);
    if (parsed['numeric'] != null) { numeric = parsed['numeric']; dnsEnable = !numeric; }
    if (parsed['cycles'] != null) {
      int cnt = int.parse(parsed['cycles']);
      if (cnt <= 0) throw 'Number($cnt) of cycles must be great than 0';
      count = cnt;
    }
    if (parsed['report'] != null) {
      reportEnable = parsed['report'];
      if (reportEnable) count ??= reportCycles;
    }
    if (parsed['json'] != null) {
      jsonEnable = parsed['json'];
      if (jsonEnable) count ??= reportCycles;
    }
    if (parsed['size'] != null) {
      var (e, _) = parsePsize(parsed['size']);
      if (e != null) { throw e; }
      else { pszopt = psize; }
    }
    if (parsed['ttl'] != null) {
      var (e, _) = parseTTL(parsed['ttl']);
      if (e != null) { throw e; }
      else { ftlopt = firstTTL; ltlopt = lastTTL; }
    }
    if (parsed['qos'] != null) {
      var (e, _) = parseQoS(parsed['qos']);
      if (e != null) { throw e; }
      else { qosopt = qos; }
    }
    if (parsed['interval'] != null) {
      interval = int.parse(parsed['interval']);
      if (interval <= 0) throw 'Interval($interval) in seconds must be great than 0';
    }
    ipv4only = parsed['ipv4'] ? true : null;
    ipv6only = parsed['ipv6'] ? true : null;
    if (parsed['help'] ?? false) usage(myname, parser.usage, 4);
    if (parsed['syslog'] ?? false) {
      { final failed = await probeSyslogger(); if (failed != null) { print(failed); exit(-1); }}
      logger = Syslogger(id: pid, tag: myname);
    }
    if (parsed.rest.isEmpty) throw "TARGET host is not set";
    optstr = args.where((a) => !parsed.rest.contains(a)).join(' ');
    targets = parsed.rest;
    logger?.p('parsed CLI args: ${parsed.arguments}');
  } catch(e) {
    print("$myname: $e\n");
    usage(myname, parser.usage, 4);
  }

  displayMode = !(reportEnable || jsonEnable);
  if (displayMode && !openDisplay()) return -1;
  List json = [];
  for (var i = 0; i < targets.length; i++) { // note: one by one, not async
    title = targets[i];
    await pingHops(targets[i]); // Run main loop
    if (reportEnable) { // Print plain report
      logger?.p('print plain report');
      if (i != 0) print('');
      String now = '${DateTime.now()}';
      now = now.substring(0, now.indexOf('.'));
      if (fails.isNotEmpty) { print('[$now] ${fails.join(", ")}'); fails = []; }
      else { print("[$now] $title"); printReport(stat, hops); }
    }
    if (jsonEnable) json.add(getMappedHops(stat, hops, targets[i])); // Add mapped stats for a target
  }
  if (displayMode) {
    closeDisplay();
    if (fails.isNotEmpty) for (var e in fails) { print('$myname: $e'); }
  }
  if (jsonEnable) { // Print report in JSON format
    logger?.p('print stats in json format');
    var encoder = JsonEncoder.withIndent('  ');
    print(encoder.convert(json));
  }
}

