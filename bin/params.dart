
import 'dart:io' show Platform;
import 'syslogger.dart' show Syslogger;

final myname = (Platform.executable == 'dart') ? 'dmtr' : Platform.executable;
final version = '0.1.38';
String? optstr;
String? addnote;
bool pause = false;
bool gotdata = false; // true after getting any first reply

// options can be reset with program args, below are defaults
bool? ipv4only;            // -4
bool? ipv6only;            // -6
bool dnsEnable = true;     // -n
int? count;                // -c count
bool reportEnable = false; // -r
bool jsonEnable = false;   // -j
int interval = 1;          // -i seconds
int firstTTL = 1;          // -t minTTL,maxTTL
int lastTTL = maxTTL;      //
int? psize;                // -s payload size
String? payload;           // -p payload pattern
int? qos;                  // -Q QoS/ToS bits
Syslogger? logger;         // --syslog

// default params
const maxTTL = 30; // suppose it's enough for today's internet
// payload size in bytes: default=56, min=sizeof(struct timeval), max=(typical_highest_mtu - iph_sz - icmph_sz)
final psize_ = (def: 56, min: 16, max: 9000 - 20 - 8);
bool numeric = false;      // not toggled dnsEnable
int ftlopt = firstTTL;     // not toggled '-t' arg: firstTTL
int ltlopt = lastTTL;      // not toggled '-t' arg: lastTTL
int? pszopt;               // not toggled '-s' arg
String? pldopt;            // not toggled '-p' arg
int? qosopt;               // not toggled '-q' arg
int? cntopt;               // not toggled '-c' arg
bool displayMode = true;   // if neither 'reportEnable' nor 'jsonEnable'
const reportCycles = 10;   // for a report in json format and a plain one
bool paramsChanged = false; // indicator of customization

