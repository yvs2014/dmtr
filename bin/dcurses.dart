
import 'dart:io' show sleep;
import 'dart:convert' show utf8;
import 'package:sprintf/sprintf.dart' show sprintf;
import 'libncurses.dart';
import 'common.dart';

late Voidptr _win;

typedef _KeyHint = ({String key, String hint});
List<_KeyHint> _keyhints = [
  (key: 'help',  hint: 'this help'),
  (key: 'dns',   hint: 'toggle hostname/ipaddr show (note: on linux it works only in non-numeric mode)'),
  (key: 'ttl',   hint: 'set ttl range in min,max format [TODO]'),
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

String? parseMinMaxTTL(String s) {
  try {
    var mm = s.split(',');
    if (mm.isNotEmpty) {
      if (mm[0].isNotEmpty) {
        int n = int.parse(mm[0]);
        if ((n > 0) && (n <= maxTTL)) { firstTTL = n; }
        else { return 'Min TTL ($n) is out of range 1..$maxTTL'; }
      }
      if ((mm.length > 1) && mm[1].isNotEmpty) {
        int n = int.parse(mm[1]);
        if ((n >= firstTTL) && (n <= maxTTL)) { lastTTL = n; }
        else { return 'Max TTL ($n) is out of range $firstTTL..$maxTTL'; }
      }
    }
  } catch (e) { return '$e'; }
  return null;
}

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

const _kEnter = 10;
const _kBackspace = 127;

void keyTTL() {
  const prompt = 'Enter TTL range: ';
  pause = true;
  clear();
  int y = 2, x = 1;
  mvaddstr(y, x, prompt);
  List<int> input = [];
  echo();
  while (true) {
    int c = getch();
    if (c > 0) {
      if (c == _kEnter) break; // Enter
      if (c == _kBackspace) {  // Backspace
        if (input.isNotEmpty) input.removeLast();
        int xi = x + prompt.length + input.length;
        mvaddstr(y, xi, '     '); move(y, xi);
        continue;
      }
      input.add(c);
      if (input.length > (cols - prompt.length - 2 * x)) break; // too many
    }
    sleep(Duration(milliseconds: 50));
  }
  noecho();
  if (input.isNotEmpty) {
    var e = parseMinMaxTTL(utf8.decode(input).trim());
    if (e == null) { addnote = 'TTL range: $firstTTL..$lastTTL'; }
    else { mvaddstr(y + 2, x, 'ERROR: $e'); refresh(); sleep(Duration(seconds: 3)); }
  }
  pause = false;
}

int printTitle(int y0, int w, {bool over = false, bool up = false}) {
  int y = y0;
  attron(aBold);
  { // firstly print program name and its arguments
    List<String?> parts = [title];
    if (numeric != !dnsEnable) parts.add('(DNS-${dnsEnable ? "on" : "off"})');
    if (addnote != null) parts.add(addnote);
    if (!gotdata) parts.add(': no data yet');
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

void showStat(String host, List<Hop> stat, int hops) {
  if (!displayMode) return;
  int w = cols - (lindent + statMax + 2);
  if (pause) { printTitle(0, w, over: true); }
  else {
    clear();
    int y = printTitle(0, w);
    if ((hops > 0) && gotdata) {
      int end = (hops < lastTTL) ? hops : lastTTL;
      for (int i = firstTTL - 1; i < end; i++) {
        String no = sprintf('%2d. ', [i + 1]);
        String addr = stat[i].addr.isNotEmpty ? stat[i].lpart(0) : '';
        mvaddstr(y++, 0, sprintf('%*s%-*.*s %s', [lindent, no, w, w, addr, stat[i].rpart]));
        for (int j = 1; j < stat[i].addr.length; j++) {
          mvaddstr(y++, 0, sprintf('%*s%s', [lindent, '', stat[i].lpart(j)]));
        }
        if (stat[i].unreach) mvaddstr(y++, 0, sprintf('%*s%s', [lindent, '', unreachMesg]));
      }
    }
    refresh();
  }
}

