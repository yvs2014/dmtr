
import 'package:sprintf/sprintf.dart' show sprintf;
import 'package:ncurses/ncurses.dart' show defaultLibrary, Screen, Window, Position, CursorVisibility;
import 'common.dart';

late Screen _screen;
late Window _window;

final hopHeader = sprintf('%-*s\t%s\t%s\t%s', [hostnameLen, 'Host', 'Sent', 'Rcvd', 'Last']);
String? _host;

void openDisplay() {
  _screen = Screen();
  _screen.raw = true;
  _screen.cursorVisibility = CursorVisibility.invisible;
  _screen.echo = false;
  _screen.window.noDelay = true;
  _window = _screen.window;
}

void closeDisplay() { _window.addString('\n');  _window.refresh(); _screen.endWin(); }

void setDisplayHost(String host) { _host = host; }

String? getKey() {
  int c = defaultLibrary.getch();
  return (c > 0) ? String.fromCharCode(c) : null;
}

void showStat({int indent = 4, String? header, required List<Hop> stat, required int hops, String? target}) {
  if (hops > 0) {
    _window.clear();
    int y = 0;
    if (_host != null) _window.addString(at: Position(0, y++), 'Ping $_host');
    _window.addString(at: Position(0, y++), sprintf('%*s%s', [indent, '', header ?? hopHeader]));
    for (int i = 0; i < hops; i++) {
      String no = sprintf('%2d. ', [i + 1]);
      _window.addString(at: Position(0, y++), sprintf('%*s%s', [indent, no, (stat[i].data.sent > 0) ? stat[i] : '']));
    }
    _window.refresh();
  }
}

