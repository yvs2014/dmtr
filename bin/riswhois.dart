
import 'dart:io' show Socket;
import 'dart:async' show Completer;
import 'dart:convert' show LineSplitter;
import 'dart:typed_data' show Uint8List;
import 'params.dart' show logger, whoKeys;


const risTimeout = 5; // in seconds
// Shorts: r - Route, a - ASN, d - Descr, c - CountryCode
typedef RIS = ({String? r, String? a, String? d, String? c});
final _k = (a: 'origin', c: 'cc', d: 'descr', r: 'route'); // maps of keys in whois response
final _titleMap = {'a': [_k.a, 'AS'], 'c': [_k.c, 'CC'], 'd': [_k.d, 'Company'], 'r': [_k.r, 'Route']}; // auxiliary map


Future<RIS?> risWhois(String addr, { int? port, int? tout}) async {
  const sc = ':';    // delimiter of 'key: value'
  const c = ',';     // delimiter of 'description, country'
  const skip = '%';  // comment line
  const splitter = LineSplitter();
  final Completer<RIS?> completer = Completer<RIS?>();
  logger?.p('whois request: $addr');
  final socket = await Socket.connect("riswhois.ripe.net", port ?? 43, timeout: Duration(seconds: tout ?? risTimeout));
  List<String> together = [];
  socket.listen((Uint8List data) { together += splitter.convert(String.fromCharCodes(data)); },
    onError: (e) { socket.destroy(); completer.complete(null); logger?.p('whois sock: $e'); },
    onDone: () {
      socket.destroy();
      together.removeWhere((l) => (l.isEmpty || (l[0] == skip) || !l.contains(sc)));
      Map<String, String?> map = {};
      for (var l in together) {
        final pair = l.split(sc);
        if (pair.length < 2) continue;
        final k = pair.removeAt(0).trim();
        var v = pair.join(sc);
        if (k == _k.d) { // extract CountryCode
          final sub = v.split(c);
          if (sub.length > 1) {
            var cc = sub.last;
            sub.remove(cc);
            if (cc.isNotEmpty) map[_k.c] = cc.trim();
            v = sub.join(c);
          }
        }
        v = v.trim();
        if (v.isNotEmpty) map[k] = v;
      }
      for (var e in _titleMap.entries) { // pad titles with blanks according to the longest value
        var s = e.value[1];
        int l = map[e.value[0]]?.length ?? 0;
        if (s.length < l) _titleMap[e.key]?[1] = s.padRight(l);
      }
      completer.complete((r: map[_k.r], a: map[_k.a], d: map[_k.d], c: map[_k.c]));
    }
  );
  socket.write('-m $addr\r\n');
  logger?.p('whois complete: $addr');
  return completer.future;
}

Map<String, dynamic> info2map(RIS info) {
  Map<String, dynamic> m = {};
  for (var c in whoKeys?.split('') ?? []) {
    switch (c) {
      case 'a': m[_k.a] = info.a;
      case 'c': m[_k.c] = info.c;
      case 'd': m[_k.d] = info.d;
      case 'r': m[_k.r] = info.r;
    }
  }
  m.removeWhere((k, v) => (v == null) ? true : ((v is String) ? v.isEmpty : false));
  return m;
}

String who2titles(String title) {
  if (whoKeys == null) return title;
  List<String?> re = [];
  for (var c in whoKeys?.split('') ?? []) { re.add(_titleMap[c]?[1]); }
  re.add(title);
  re.removeWhere((s) => s == null);
  return re.join(' ');
}

String _padInfo(String? s, String c) => (s ?? '??').padRight(_titleMap[c]?[1].length ?? 0);

String who2info(RIS? info) {
  List<String?> re = [];
  for (var c in whoKeys?.split('') ?? []) {
    switch (c) {
      case 'a': re.add(_padInfo(info?.a, c));
      case 'c': re.add(_padInfo(info?.c, c));
      case 'd': re.add(_padInfo(info?.d, c));
      case 'r': re.add(_padInfo(info?.r, c));
    }
  }
  re.removeWhere((s) => s == null);
  return re.join(' ');
}

