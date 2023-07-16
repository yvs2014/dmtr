
import 'dart:io' show sleep;
import 'package:sprintf/sprintf.dart' show sprintf;
import 'libncurses.dart';
import 'common.dart';

late Voidptr _win;

typedef _KeyHint = ({String key, String hint});
List<_KeyHint> _keyhints = [
  (key: 'help',  hint: 'this help'),
  (key: 'dns',   hint: 'toggle hostname/ipaddr show (note: on linux it works only in non-numeric mode)'),
  (key: 'ttl',   hint: 'set ttl range in min,max format'),
  (key: 'reset', hint: 'reset stats'),
  (key: 'pause', hint: 'pause/resume'),
  (key: 'quit',  hint: 'stop and exit'),
];
int _maxHKey = _keyhints.reduce((a, b) { return a.key.length > b.key.length ? a : b; }).key.length;

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

void keyHelp() {
  pause = true;
  clear();
  int ind = 2, y = 2, x0 = 1, x = x0 + ind + _maxHKey + 2;
  mvaddstr(y++, x0, 'Keys:');
  for (var h in _keyhints) {
    if (h.key.isNotEmpty) {
      attron(aBold); mvaddstr(y, x0 + ind, h.key[0]); attroff(aBold);
      if (h.key.length > 1) addstr(h.key.substring(1));
      mvaddstr(y++, x, h.hint);
    }
  }
  y++;
  mvaddstr(y++, x0, 'Press any key to continue ...');
  refresh();
  while (getch() < 0) { sleep(Duration(milliseconds: 200)); }
  pause = false;
}

int printTitle(int y0, int w, {bool over = false, bool up = false}) {
  int y = y0;
  attron(aBold);
  { // firstly print program name and its arguments
    List<String?> parts = [title];
    if (numeric != !dnsEnable) parts.add('(DNS-${dnsEnable ? "on" : "off"})');
    if (addnote != null) parts.add(addnote);
    if (over) { move(y, 0); clrtoeol(); }
    { String s = parts.where((p) => (p != null) && p.isNotEmpty).join(' ');
      mvaddstr(y++, 0, sprintf('%*s', [(cols + s.length) ~/ 2, s])); }
  }
  if (over || up) { move(y, 0); clrtoeol(); }
  attroff(aBold);
  if (up) { refresh(); }
  else {
    { // print 'Keys Datetime' line
      mvaddstr(y, 1, 'Keys:');
      for (var h in _keyhints) {
        if (h.key.isNotEmpty) {
          attron(aBold); addstr(' ${h.key[0]}'); attroff(aBold);
          if (h.key.length > 1) addstr(h.key.substring(1));
        }
      }
      String now = '${DateTime.now()}';
      now = now.substring(0, now.indexOf('.'));
      mvaddstr(y++, cols - (now.length + 1), now);
    }
    if (!over) { // print 'Host Stat' title
      y++;
      attron(aBold);
      mvaddstr(y++, 0, sprintf('%*s%-*.*s %s', [lindent, '', w, w, hostTitle, statTitle]));
      attroff(aBold);
    }
  }
  return y - y0;
}

void showStat(List<Hop> stat, int hops, String host) {
  if (hops > 0) {
    int w = cols - (lindent + statMax + 2);
    if (pause) { printTitle(0, w, over: true); }
    else {
      clear();
      int y = printTitle(0, w);
      int end = (hops < endTtl) ? hops : endTtl;
      for (int i = firstTtl - 1; i < end; i++) {
        String no = sprintf('%2d. ', [i + 1]);
        String addr = stat[i].addr.isNotEmpty ? stat[i].lpart(0) : '';
        mvaddstr(y++, 0, sprintf('%*s%-*.*s %s', [lindent, no, w, w, addr, stat[i].rpart]));
        if (stat[i].addr.length > 1) {
          for (int j = 1; j < stat[i].addr.length; j++) {
            mvaddstr(y++, 0, sprintf('%*s%s', [lindent, '', stat[i].lpart(j)]));
          }
        }
      }
    }
    refresh();
  }
}

