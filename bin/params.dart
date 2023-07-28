
import 'dart:io' show Platform;
import 'syslogger.dart' show Syslogger;

final myname = (Platform.executable == 'dart') ? 'dmtr' : Platform.executable;
final version = '0.1.31';
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
int? psize;                // -s payload size
Syslogger? logger;         // --syslog

// default params
const maxTTL = 30; // suppose it's enough for today's internet
// payload in bytes: default=56, min=sizeof(struct timeval), max=(uint16_t - iph_sz - icmph_sz)
final psize_ = (def: 56, min: 16, max: 65535 - 20 - 8);
bool numeric = false;      // not toggled dnsEnable
bool displayMode = true;   // if neither 'reportEnable' nor 'jsonEnable'
const reportCycles = 10;   // for a report in json format and a plain one
int lastTTL = maxTTL;      //

// misc
//List<String?> fails = []; // message(s) if something went wrong (for example 'unknown host')
//void addFail(String? m) { if ((m != null) && !fails.contains(m)) fails.add(m); }

