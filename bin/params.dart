
import 'dart:io' show Platform;
import 'syslogger.dart' show Syslogger;

get myname { var exec = Platform.executable.split('/').last; return (exec == 'dart') ? 'dmtr' : exec; }
final version = '0.1.46';
String? optstr;
String? addnote;
bool pause = false;
bool gotdata = false; // true after getting any first reply

// options can be reset with program args, below are defaults
// without args
bool? ipv4only;            // -4
bool? ipv6only;            // -6
bool dnsEnable = true;     // -n
bool reportEnable = false; // -r
bool jsonEnable = false;   // -j
Syslogger? logger;         // --syslog
// with args
String? addrface;          // -a addr|iface
int? count;                // -c count
int interval = 1;          // -i seconds
int firstTTL = 1;          // -t minTTL,maxTTL
int lastTTL = maxTTL;      //
String? payload;           // -p payload pattern
int? qos;                  // -q QoS/ToS bits
int? psize;                // -s payload size
String? whoKeys;           // -w riswhois-keys (default: CC, ASN)
String whoKeysDef = 'ca';  //    default if not specified

// default params
const maxTTL = 30; // suppose it's enough for today's internet
// payload size in bytes: default=56, min=sizeof(struct timeval), max=(typical_highest_mtu - iph_sz - icmph_sz)
final psize_ = (def: 56, min: 16, max: 9000 - 20 - 8);
bool numeric = false;      // not toggled dnsEnable
int? cntopt;               // not toggled '-c' arg
int ivalopt = interval;    // not toggled '-i' arg
String? pldopt;            // not toggled '-p' arg
int? qosopt;               // not toggled '-q' arg
int? pszopt;               // not toggled '-s' arg
int ftlopt = firstTTL;     // not toggled '-t' arg: firstTTL
int ltlopt = lastTTL;      // not toggled '-t' arg: lastTTL
String? whoopt = whoKeys;  // not toggled '-w' arg
bool displayMode = true;   // if neither 'reportEnable' nor 'jsonEnable'
const reportCycles = 10;   // for a report in json format and a plain one
bool paramsChanged = false; // indicator of customization

