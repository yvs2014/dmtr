
import 'dart:io' show Platform, Process, ProcessSignal, ProcessException;
import 'dart:async' show StreamController, StreamSubscription, StreamTransformer;
import 'dart:convert' show Utf8Decoder, LineSplitter;
import 'package:async/async.dart' show StreamGroup;

enum Status { undefined, success, discard, timeout, unknown }
const utfenv = {'LC_ALL': 'C.UTF-8'};
const sysping = 'ping';
String? _sysping6;

Future<dynamic> probeSysping() async {
  try { Process.runSync(sysping, []); }
  on ProcessException catch (e) { return '${e.executable}: ${e.message}'; }
  catch (e) { return e; }
  try { Process.runSync('${sysping}6', []); }
  catch (_) { _sysping6 = '${sysping}6'; }
  return null;
}

class Data {
  const Data({this.status = Status.undefined, this.seq, this.ttl, this.addr, this.name, this.ts, this.time, this.mesg, this.rc});
  final Status status;
  final int? seq;
  final int? ttl;
  final String? addr;
  final String? name;
  final String? ts;
  final Duration? time;
  final String? mesg;
  final int? rc; // exit code
}

typedef _TrRegexp = ({RegExp contain, RegExp? match});

_TrRegexp _osDependedDiscard() {
  if (Platform.isLinux) { return (contain: RegExp(r'^(\[(?<ts>.*)\] )*From'),
    match: RegExp(r'^\[(?<ts>[0-9.]+)\] From (((?<name>.*) \((?<addr>.*)\))|(?<ip>.*)) icmp_seq=(?<seq>\d+) (?<mesg>.*)')); }
  if (Platform.isMacOS) { return (contain: RegExp(r' bytes from .*: (?!icmp_seq=)'),
    match: RegExp(r'^(?<ts>[0-9.:]+) .* bytes from (((?<name>.*) \((?<addr>.*)\))|(?<ip>.*)): (?<mesg>.*)')); }
  throw UnimplementedError('Platform ${Platform.operatingSystem} is not supported (yet)');
}

_TrRegexp _osDependedTimeout() {
  if (Platform.isLinux) { return (contain: RegExp(r'no answer yet'),
    match: RegExp(r'^\[(?<ts>[0-9.]+)\] .*icmp_seq=(?<seq>\d+)')); }
  if (Platform.isMacOS) { return (contain: RegExp(r'Request timeout'),
    match: RegExp(r'^(?<ts>[0-9.:]+) ')); }
  throw UnimplementedError('Platform ${Platform.operatingSystem} is not supported (yet)');
}

final Map<Status, _TrRegexp> _tre = { // regexps for transformer (linux, macos)
  Status.success: (contain: RegExp(r' bytes from .*: icmp_seq='),
    match: RegExp(r'from (((?<name>.*) \((?<addr>.*)\))|(?<ip>.*)): icmp_seq=(?<seq>\d+) ttl=(?<ttl>\d+) time=(?<time>(\d+).?(\d+))')),
  Status.discard: _osDependedDiscard(),
  Status.timeout: _osDependedTimeout(),
  Status.unknown: (contain: RegExp(r'[Uu]nknown host|service not known|failure in name'), match: null),
};

Map<String, dynamic> _osDependedOpts() {
  if (Platform.isLinux) return {'ttl': '-t', 'ts': '-OD', 'v6': '-6'};
  if (Platform.isMacOS) return {'ttl': '-m', 'ts': '--apple-time', 'factor': 1000};
  throw UnimplementedError('Platform ${Platform.operatingSystem} is not supported (yet)');
}
final _osOpts = _osDependedOpts();

class Ping {
  Ping(host, { int? count, int dt = 1, int ttl = 30, bool dns = true, bool ipv6 = false}) {
    _args.add('-i $dt');
    if (!dns) _args.add('-n');
    if (count != null) _args.add('-c $count');
    if (ipv6) {
      if (_osOpts.containsKey('v6')) { _args.add(_osOpts['v6']); }
      else if (_sysping6 == null) { throw UnimplementedError('${sysping}6 is not found'); }
      else { pingname = _sysping6!; }
    }
    if (_osOpts.containsKey('factor')) dt = (dt * _osOpts['factor']).toInt();
    _args.add('-W $dt');
    _args.add("${_osOpts['ttl']} $ttl");
    _args.add("${_osOpts['ts']}");
    _args.add(host);
    _cntr = StreamController<Data>(
      onListen: _onListen,
      onPause: () => _sub.pause,
      onResume: () => _sub.resume,
      onCancel: () => _process.kill(ProcessSignal.sigint),
    );
  }

  String pingname = sysping;
  late Process _process;
  final List<String> _args = [];

  late final StreamController<Data> _cntr;
  final StreamTransformer<String, Data> _tf = transformer;
  Stream<Data> get _datastream => StreamGroup.merge([_process.stderr, _process.stdout])
    .transform(Utf8Decoder()).transform(LineSplitter()).transform<Data>(_tf);

  late final StreamSubscription<Data> _sub;
  Stream<Data> get data => _cntr.stream;

  Future<void> _onListen() async {
    _process = await Process.start(pingname, _args, environment: utfenv);
    _sub = _datastream.listen((ev) => _cntr.add(ev), onDone: _done);
  }
  Future<void> _done() async { if (!_cntr.isClosed) { _cntr.add(Data(rc: await _process.exitCode)); await _cntr.close(); }}

  Future<bool> stop() async {
    bool rc = _process.kill(ProcessSignal.sigint);
    if (rc) await _cntr.done;
    return rc;
  }
}


StreamTransformer<String, Data> get transformer => StreamTransformer<String, Data>.fromHandlers(
  handleData: (data, sink) {
    if (_withStatus(data, sink, Status.success)) return;
    if (_withStatus(data, sink, Status.discard)) return;
    if (_withStatus(data, sink, Status.timeout)) return;
    if (_tre.containsKey(Status.unknown) && data.contains(_tre[Status.unknown]!.contain))
      { sink.add(Data(status: Status.unknown, mesg: data)); } // Unknowm
    // sink.add(Data(status: Status.undefined, mesg: data)); // Other
  }
);

bool _withStatus(data, sink, Status status) {
  if (!_tre.containsKey(status)) return false;
  _TrRegexp? rgx = _tre[status];
  if ((rgx == null) || !data.contains(rgx.contain)) return false;
  final match = rgx.match?.firstMatch(data);
  if (match != null) {
    switch (status) {
      case Status.success: _fnSuccess(data, sink, match);
      case Status.discard: _fnDiscard(data, sink, match);
      case Status.timeout: _fnTimeout(data, sink, match);
	  default: {}
    }
  }
  return true;
}

String? _getTs(match) => match.groupNames.contains('ts') ? match.namedGroup('ts') : null;

(int?, String?, String?, String?) getSANT(seq, addr, match) => (
  seq?.isEmpty ?? true ? null : int.parse(seq!),
  (addr != null) ? addr : match.namedGroup('ip'),
  match.groupNames.contains('name') ? match.namedGroup('name') : null,
  _getTs(match));

void _fnSuccess(data, sink, match) {
  var seq = match.groupNames.contains('seq') ? match.namedGroup('seq') : null;
  var addr = match.groupNames.contains('addr') ? match.namedGroup('addr') : null;
  var (s,a,n,t) = getSANT(seq, addr, match);
  var ttl = match.namedGroup('ttl');
  var time = match.namedGroup('time');
  sink.add(Data(status: Status.success, seq: s, addr: a, name: n, ts: t,
    time: (time != null) ? Duration(microseconds: ((double.parse(time)) * 1000).floor()) : null,
    ttl: (ttl != null) ? int.parse(ttl) : null,
  ));
}

void _fnDiscard(data, sink, match) {
  var seq = match.groupNames.contains('seq') ? match.namedGroup('seq') : null;
  var addr = match.groupNames.contains('addr') ? match.namedGroup('addr') : null;
  var (s,a,n,t) = getSANT(seq, addr, match);
  sink.add(Data(status: Status.discard, seq: s, addr: a, name: n, ts: t, mesg: match.namedGroup('mesg')));
}

void _fnTimeout(data, sink, match) {
  var seq = match.groupNames.contains('seq') ? match.namedGroup('seq') : null;
  sink.add(Data(
    status: Status.timeout, // got timeout response
    seq: seq == null ? null : int.parse(seq),
    ts: _getTs(match),
    mesg: 'timeout',
  ));
}

