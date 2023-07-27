
import 'dart:io' show Platform, Process, ProcessException;

const _utfenv = {'LC_ALL': 'C.UTF-8'};
const _syslogger = 'logger';

Future<dynamic> probeSyslogger() async {
  try { Process.runSync(_syslogger, []); }
  on ProcessException catch (e) { return '${e.executable}: ${e.message}'; }
  catch (e) { return e; }
  return null;
}

class Syslogger {
  Syslogger({this.id, this.tag}) {
    if (!Platform.isLinux) throw Exception("Platform '${Platform.operatingSystem}' is not supported");
    if (id != null) _args.add('--id=$id');
    if (tag != null) _args.add('-t $tag');
  }
  int? id;
  String? tag;
  final List<String> _args = [];
  p(String message) => Process.run(_syslogger, _args + [message], environment: _utfenv);
  s(String message) => Process.runSync(_syslogger, _args + [message], environment: _utfenv);
//  p(String message) => print(message);
}

