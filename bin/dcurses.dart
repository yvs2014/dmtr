
import 'package:sprintf/sprintf.dart' show sprintf;
import 'libncurses.dart';
import 'common.dart';

late Voidptr _win;

String? _host;
late int _indent;
late int _hostmaxlen;

bool openDisplay({int indent = 4}) {
  _win = initscr();
  bool rc = (_win != nilptr);
  if (rc) {
    _indent = indent;
    _hostmaxlen = cols - (indent + statMax + 2);
    cursset(0); // hide cursor
    raw();
    noecho();
    nodelay(_win, true);
  } else { print('Cannot init libncurses'); }
  return rc;
}

void closeDisplay() { addstr('\n'); refresh(); endwin(); }

void setDisplayHost(String host) { _host = host; }

String? getKey() {
  int c = getch();
  return (c > 0) ? String.fromCharCode(c) : null;
}

void showStat({required List<Hop> stat, required int hops, String? target}) {
  if (hops > 0) {
    clear();
    int y = 0, w = _hostmaxlen;
    if (_host != null) mvaddstr(y++, 0, 'Ping $_host');
    attron(aBold);
    mvaddstr(y++, 0, sprintf('%*s%-*.*s %s', [_indent, '', w, w, hostTitle, statTitle]));
    attroff(aBold);
    for (int i = 0; i < hops; i++) {
      String no = sprintf('%2d. ', [i + 1]);
      String addr = stat[i].addr.isNotEmpty ? stat[i].lpart(0) : '';
      mvaddstr(y++, 0, sprintf('%*s%-*.*s %s', [_indent, no, w, w, addr, stat[i].rpart]));
      if (stat[i].addr.length > 1) {
        for (int j = 1; j < stat[i].addr.length; j++) {
          mvaddstr(y++, 0, sprintf('%*s%s', [_indent, '', stat[i].lpart(j)]));
        }
      }
    }
    refresh();
  }
}

