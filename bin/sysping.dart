
import 'dart:io' show Platform, Process, ProcessSignal, ProcessException;
import 'dart:async' show StreamController, StreamSubscription, StreamTransformer;
import 'dart:convert' show Utf8Decoder, LineSplitter;
import 'package:async/async.dart' show StreamGroup;
import 'syslogger.dart' show Syslogger;

enum Status { undefined, success, discard, timeout, unknown, error }
const _utfenv = {'LC_ALL': 'C.UTF-8'};
const _sysping = 'ping';
Syslogger? _logger;

void setSyslogger(Syslogger? logger) { _logger = logger; }

Future<dynamic> probeSysping() async {
  try { Process.runSync(_sysping, []); }
  on ProcessException catch (e) { return '${e.executable}: ${e.message}'; }
  catch (e) { return e; }
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

final Map<Status, _TrRegexp> _tre = { // regexps for transformer
  Status.success: (contain: RegExp(r'bytes from .* time='),
    match: RegExp(r'from (((?<name>.*) \((?<addr>.*)\))|(?<ip>.*)): icmp_seq=(?<seq>\d+) ttl=(?<ttl>\d+) time=(?<time>(\d+).?(\d+))')),
  Status.discard: (contain: RegExp(r'From'),
    match: RegExp(r'^\[(?<ts>[0-9.]+)\] From (((?<name>.*) \((?<addr>.*)\))|(?<ip>.*)) icmp_seq=(?<seq>\d+) (?<mesg>.*)')),
  Status.timeout: (contain: RegExp(r'no answer yet'),
    match: RegExp(r'^\[(?<ts>[0-9.]+)\] .*icmp_seq=(?<seq>\d+)')),
  Status.unknown: (contain: RegExp(r'nknown host|ervice not known|ailure in name'),
    match: null),
  Status.error: (contain: RegExp(r'^' + _sysping + r': .*:'),
    match: RegExp(r'^' + _sysping + r': .*: (?<err>.*)$')),
};


class Ping {
  Ping(host, { int interval = 1, int ttl = 30, int? count, bool? numeric, bool? ipv4, bool? ipv6}) {
    if (!Platform.isLinux) throw Exception("Platform '${Platform.operatingSystem}' is not supported");
    _args.addAll(['-i $interval', '-W $interval', '-t $ttl']);
    if (count != null) _args.add('-c $count');
    if (numeric ?? false) _args.add('-n');
    if (ipv4 ?? false) _args.add('-4');
    if (ipv6 ?? false) _args.add('-6');
    _args.add(host);
    _cntr = StreamController<Data>(
      onListen: _onListen,
      onPause: () => _sub.pause,
      onResume: () => _sub.resume,
      onCancel: () => _process.kill(ProcessSignal.sigint),
    );
  }

  late Process _process;
  final List<String> _args = ['-OD'];
  List<String> get args => _args;

  late final StreamController<Data> _cntr;
  final StreamTransformer<String, Data> _tf = transformer;
  Stream<Data> get _datastream => StreamGroup.merge([_process.stderr, _process.stdout])
    .transform(Utf8Decoder()).transform(LineSplitter()).transform<Data>(_tf);

  late final StreamSubscription<Data> _sub;
  Stream<Data> get data => _cntr.stream;

  Future<void> _onListen() async {
    _process = await Process.start(_sysping, _args, environment: _utfenv);
    _sub = _datastream.listen((ev) => _cntr.add(ev), onDone: _done);
  }
  Future<void> _done() async {
    if (!_cntr.isClosed) {
      var rc = await _process.exitCode;
      if (rc != 0) _logger?.p('$_sysping rc=$rc $args');
      _cntr.add(Data(rc: rc));
      await _cntr.close();
    }
  }

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
      { sink.add(Data(status: Status.unknown, mesg: data)); }
    if (_withStatus(data, sink, Status.error)) return;
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
      case Status.error:   _fnError(data, sink, match);
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

void _fnError(data, sink, match) =>
  sink.add(Data(status: Status.error, mesg: match.groupNames.contains('err') ? match.namedGroup('err') : null));

