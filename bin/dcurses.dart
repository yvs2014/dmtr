
import 'dart:io' show sleep;
import 'dart:convert' show utf8;
import 'package:sprintf/sprintf.dart' show sprintf;
import 'libncurses.dart';
import 'common.dart';
import 'params.dart';
import 'aux.dart';

const _kEnter = 10;
const _kBackspace = 127;
const _hkPretext = 'Keys:';

late Voidptr _win;

bool openDisplay() {
  _win = initscr(wide: true);
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
  int ind = 2, y = 2, x0 = 1, x = x0 + ind + hkMaxLen + 2;
  mvaddstr(y++, x0, _hkPretext);
  for (var h in keyhints) {
    move(y, x0 + ind);
    if (h.b > 0) addstr(h.key.substring(0, h.b));
    attron(aBold); addstr(h.key[h.b]); attroff(aBold);
    if (h.key.length > h.b) addstr(h.key.substring(h.b + 1));
    mvaddstr(y++, x, h.hint);
  }
  y++;
  mvaddstr(y++, x0, 'Press any key to continue ...');
  refresh();
  while (getch() < 0) { sleep(const Duration(milliseconds: 200)); }
  pause = false;
}

typedef _InputFn = (String?, String?) Function(String input);

void _getInput(String what, _InputFn fn) {
  final prompt = 'Enter $what: ';
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
    sleep(const Duration(milliseconds: 50));
  }
  noecho();
  if (input.isNotEmpty) {
    var (e, a) = fn(utf8.decode(input).trim());
    if ((a != null) && paramsChanged) addnote = '$what: $a';
    if (e != null) {
      mvaddstr(y + 2, x, 'ERROR: $e');
      refresh();
      logger?.p('input error: $e');
      sleep(const Duration(seconds: 3));
    }
  }
  pause = false;
}

void keyCycles() => _getInput('cycles', parseCycles);
void keyFields() => _getInput('stat fields', parseStatKeys);
void keyIval() => _getInput('interval', parseIval);
void keyPayload() => _getInput('payload pattern', parsePayload);
void keyQoS() => _getInput('QoS/ToS bits', parseQoS);
void keySize() => _getInput('payload size', parseSize);
void keyTTL() => _getInput('TTL range', parseTTL);
void keyWhois() => _getInput('RIS whois keys', parseWhoKeys);

int printTitle(int y0, int w, {bool over = false, bool up = false}) {
  int y = y0;
//  attron(aBold);
  { // firstly print program name and its arguments
    List<String?> parts = [title];
    List<String?> subs = [];
    if (numeric != !dnsEnable) subs.add('DNS ${dnsEnable ? "on" : "off"}');
    if (count != cntopt) subs.add('cycles $count');
    if (statKeys != statopt) subs.add("fields '$statKeys'");
    if (interval != ivalopt) subs.add('interval ${interval}s');
    if ((firstTTL != ftlopt) || (lastTTL != ltlopt)) subs.add('TTL $firstTTL..$lastTTL');
    if (qos != qosopt) subs.add('QoS $qos');
    if (psize != pszopt) subs.add('psize $psize');
    if (payload != pldopt) subs.add('payload $payload');
    if (whoKeys != whoopt) subs.add("whois '$whoKeys'");
    if (subs.isNotEmpty) { var s = subs.where((p) => (p != null) && p.isNotEmpty).join(', '); parts.add('($s)'); }
    if (addnote != null) parts.add(addnote);
    if (!gotdata && running) parts.add(': ${msgs.nodata} yet');
    if (over) { move(y, 0); clrtoeol(); }
    { var s = parts.where((p) => (p != null) && p.isNotEmpty).join(' ');
      mvaddwstr(y++, 0, sprintf('%*s', [(cols + s.length) ~/ 2, s])); }
  }
  if (over || up) { move(y, 0); clrtoeol(); }
//  attroff(aBold);
  if (up) { refresh(); }
  else {
    { // print 'Keys Datetime' line
      int x0 = 1;
      mvaddstr(y, x0, _hkPretext);
      String now = '${DateTime.now()}';
      now = now.substring(0, now.indexOf('.'));
      int xnow = cols - (now.length + 1);
      if (hkTotal < (xnow - (_hkPretext.length + x0 + 2))) {
        for (var h in keyhints) {
          addstr(' ');
          if (h.b > 0) addstr(h.key.substring(0, h.b));
          attron(aBold); addstr(h.key[h.b]); attroff(aBold);
          if (h.key.length > h.b) addstr(h.key.substring(h.b + 1));
        }
      } else {
        addstr(' '); attron(aBold); addstr('h'); attroff(aBold); addstr('ints');
        addstr(' e'); attron(aBold); addstr('x'); attroff(aBold); addstr('it');
      }
      mvaddstr(y++, xnow, now);
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
  int w = (cols - (lindent + statTitle.length + 2)).toInt();
  if (pause) { printTitle(0, w, over: true); }
  else {
    clear();
    int y = printTitle(0, w);
    if ((hops > 0) && gotdata) {
      List<PongData> pongs = [];
      bool pong = true;
      int end = (hops < lastTTL) ? hops : lastTTL;
      for (int i = firstTTL - 1; i < end; i++) {
        List<String> data = [];
        pong = stat[i].info.isNotEmpty;
        String no = sprintf('%2d. ', [i + 1]);
        String addr = pong ? stat[i].lpart(0) : '';
        data.add(sprintf('%*s%-*.*s %s', [lindent, no, w, w, addr, stat[i].rpart]));
        for (int j = 1; j < stat[i].info.length; j++) {
          data.add(sprintf('%*s%s', [lindent, '', stat[i].lpart(j)])); }
        if (!stat[i].reachable) data.add(msgs.unreach);
        var mesg = stat[i].wrong;
        if (mesg != null) data.add(msgs.wrong(mesg));
        pongs.add((pong: pong, data: data));
      }
      if (!pong) try { trimTail(pongs); } catch (_) {}
      for (var p in pongs) { for (var s in p.data) { mvaddstr(y++, 0, s); }}
    }
    refresh();
  }
}

