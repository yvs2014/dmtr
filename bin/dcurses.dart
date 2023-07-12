
import 'package:sprintf/sprintf.dart' show sprintf;
import 'libncurses.dart';
import 'common.dart';

late Voidptr _win;

bool openDisplay() {
  _win = initscr();
  bool rc = (_win != nilptr);
  if (rc) {
    cursset(0); // hide cursor
    raw();
    noecho();
    nodelay(_win, true);
  } else { print('Cannot init libncurses'); }
  return rc;
}

void closeDisplay() { addstr('\n'); refresh(); endwin(); }

String? getKey() {
  int c = getch();
  return (c > 0) ? String.fromCharCode(c) : null;
}

int _printTitle(int y0, int w) {
  int y = y0;
  attron(aBold);
  mvaddstr(y++, 0, sprintf('%*s', [(cols + (title?.length ?? 0)) ~/ 2, title ?? '']));
  attroff(aBold);
  mvaddstr(y, 0, ' Keys: ');
  attron(aBold); addstr('H'); attroff(aBold); addstr('elp ');
  if (!numeric) { attron(aBold); addstr('D'); attroff(aBold); addstr('ns '); }
  attron(aBold); addstr('T'); attroff(aBold); addstr('tl ');
  attron(aBold); addstr('P'); attroff(aBold); addstr('ause ');
  attron(aBold); addstr('R'); attroff(aBold); addstr('eset ');
  attron(aBold); addstr('Q'); attroff(aBold); addstr('uit');
  String now = '${DateTime.now()}';
  now = now.substring(0, now.indexOf('.'));
  mvaddstr(y++, cols - (now.length + 1), now);
  y++;
  attron(aBold);
  mvaddstr(y++, 0, sprintf('%*s%-*.*s %s', [lindent, '', w, w, hostTitle, statTitle]));
  attroff(aBold);
  return y - y0;
}

void showStat(List<Hop> stat, int hops, String host) {
  if (hops > 0) {
    clear();
    int w = cols - (lindent + statMax + 2);
    int y = _printTitle(0, w);
    for (int i = 0; i < hops; i++) {
      String no = sprintf('%2d. ', [i + 1]);
      String addr = stat[i].addr.isNotEmpty ? stat[i].lpart(0) : '';
      mvaddstr(y++, 0, sprintf('%*s%-*.*s %s', [lindent, no, w, w, addr, stat[i].rpart]));
      if (stat[i].addr.length > 1) {
        for (int j = 1; j < stat[i].addr.length; j++) {
          mvaddstr(y++, 0, sprintf('%*s%s', [lindent, '', stat[i].lpart(j)]));
        }
      }
    }
    refresh();
  }
}

