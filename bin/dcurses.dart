
import 'package:sprintf/sprintf.dart' show sprintf;
import 'package:ncurses/ncurses.dart' show defaultLibrary, Screen, Window, Position, CursorVisibility, /*lines,*/ columns;
import 'common.dart';

late Screen _screen;
late Window _window;

String? _host;
late int _indent;
late int _hostmaxlen;

void openDisplay({int indent = 4}) {
  _screen = Screen();
  _screen.raw = true;
  _screen.cursorVisibility = CursorVisibility.invisible;
  _screen.echo = false;
  _screen.window.noDelay = true;
  _window = _screen.window;
  _indent = indent;
  _hostmaxlen = columns - (indent + statMax + 2);
}

void closeDisplay() { _window.addString('\n');  _window.refresh(); _screen.endWin(); }

void setDisplayHost(String host) { _host = host; }

String? getKey() {
  int c = defaultLibrary.getch();
  return (c > 0) ? String.fromCharCode(c) : null;
}

void showStat({required List<Hop> stat, required int hops, String? target}) {
  if (hops > 0) {
    _window.clear();
    int y = 0, w = _hostmaxlen;
    if (_host != null) _window.addString(at: Position(0, y++), 'Ping $_host');
    _window.addString(at: Position(0, y++), sprintf('%*s%-*.*s %s', [_indent, '', w, w, hostTitle, statTitle]));
    for (int i = 0; i < hops; i++) {
      String no = sprintf('%2d. ', [i + 1]);
      _window.addString(at: Position(0, y++), sprintf('%*s%-*.*s %s', [_indent, no, w, w, stat[i].lpart, stat[i].rpart]));
    }
    _window.refresh();
  }
}

