
import 'dart:io' show Platform;
import 'dart:ffi';
import 'package:ffi/ffi.dart';

final nilptr = nullptr;
typedef Voidptr = Pointer<Void>;
typedef Intptr = Pointer<Int>;
typedef Charptr = Pointer<Char>;
typedef WCharptr = Pointer<WChar>;

const _dclib = (legacy: 'curses', std: 'ncurses', wide: 'ncursesw');
const _libext = ['so.6', 'so'];

const cOK = 0;
const cERR = -1;
const cAttrShift = 8;
const aBold = 1 << (13 + cAttrShift);
const _cLCALL = 6; // LC_ALL

String? _currlib;
DynamicLibrary _dynload(List<String> names) {
  if (!Platform.isLinux) throw Exception("Platform '${Platform.operatingSystem}' is not supported");
  List errs = [];
  for (var lib in names) {
    _currlib = lib;
    for (var so in _libext) {
      try { return DynamicLibrary.open('lib$lib.$so'); }
      catch (e) { errs.add(e); }
    }
  }
  for (var e in errs) { print(e); }
  throw Exception("No one library can be loaded: ${names.join(', ')}");
}

late final DynamicLibrary _libc;
late final DynamicLibrary _libncurses;
late final bool _widelib;
get widelib => _widelib;

// C functions' wrapping
String setlocale(int lc, String str) {
  final cstr = str.toNativeUtf8().cast<Char>();
  final re = _setlocale(lc, cstr);
  calloc.free(cstr);
  return re.cast<Utf8>().toDartString();
}
Voidptr initscr({bool wide = false}) {
  final List<String> names = wide ? [_dclib.wide, _dclib.std] : [_dclib.std, _dclib.wide];
  _libncurses = _dynload(names + [_dclib.legacy]);
  bool probe = wide && (_currlib == _dclib.wide);
  if (probe) {
    try { _libc = _dynload(['c']); setlocale(_cLCALL, ''); }
    catch (_) { probe = false; }
  }
  _widelib = probe;
  return _initscr();
}
int endwin() => _endwin();
void clear() => _clear();
void refresh() => _refresh();
int attron(int attrs) => _attron(attrs);
int attroff(int attrs) => _attroff(attrs);
int raw() => _raw();
int noraw() => _noraw();
int echo() => _echo();
int noecho() => _noecho();
int nodelay(Voidptr win, bool bf) => _nodelay(win, bf);
int cursset(int visibility) => _cursset(visibility);
int get lines => _lines.value;
int get cols => _cols.value;
int getch() => _getch();
int clrtoeol() => _clrtoeol();
int move(int y, int x) => _move(y, x);
//int addch(int ch) => _addch(ch);
int addstr(String str) {
  final cstr = str.toNativeUtf8().cast<Char>();
  final int rc = _addstr(cstr);
  calloc.free(cstr);
  return rc;
}
int mvaddstr(int y, int x, String str) {
  final cstr = str.toNativeUtf8().cast<Char>();
  final int rc = _mvaddstr(y, x, cstr);
  calloc.free(cstr);
  return rc;
}
int mvaddwstr(int y, int x, String str) {
  if (!_widelib) return mvaddstr(y, x, str);
  var l = str.length;
  var wstr = malloc<WChar>(l + 1);
  for (int i = 0; i < l; i++) { wstr[i] = str.codeUnitAt(i); } wstr[l] = 0;
  final int rc = _mvaddwstr(y, x, wstr);
  calloc.free(wstr);
  return rc;
}


// FFI bindings
final _setlocale = _libc
  .lookup<NativeFunction<Charptr Function(Int, Charptr)>>('setlocale')
  .asFunction<Charptr Function(int, Charptr)>();
final _initscr = _libncurses
  .lookup<NativeFunction<Voidptr Function()>>('initscr')
  .asFunction<Voidptr Function()>();
final _endwin = _libncurses
  .lookup<NativeFunction<Int Function()>>('endwin')
  .asFunction<int Function()>();
final _clear = _libncurses
  .lookup<NativeFunction<Int Function()>>('clear')
  .asFunction<int Function()>();
final _refresh = _libncurses
  .lookup<NativeFunction<Int Function()>>('refresh')
  .asFunction<int Function()>();
final _attron = _libncurses
  .lookup<NativeFunction<Int Function(Int)>>('attron')
  .asFunction<int Function(int)>();
final _attroff = _libncurses
  .lookup<NativeFunction<Int Function(Int)>>('attroff')
  .asFunction<int Function(int)>();
final _raw = _libncurses
  .lookup<NativeFunction<Int Function()>>('raw')
  .asFunction<int Function()>();
final _noraw = _libncurses
  .lookup<NativeFunction<Int Function()>>('noraw')
  .asFunction<int Function()>();
final _echo = _libncurses
  .lookup<NativeFunction<Int Function()>>('echo')
  .asFunction<int Function()>();
final _noecho = _libncurses
  .lookup<NativeFunction<Int Function()>>('noecho')
  .asFunction<int Function()>();
final _nodelay = _libncurses
  .lookup<NativeFunction<Int Function(Voidptr, Bool)>>('nodelay')
  .asFunction<int Function(Voidptr, bool)>();
final _cursset = _libncurses
  .lookup<NativeFunction<Int Function(Int)>>('curs_set')
  .asFunction<int Function(int)>();
final Intptr _lines = _libncurses.lookup<Int>('LINES');
final Intptr _cols = _libncurses.lookup<Int>('COLS');
final _getch = _libncurses
  .lookup<NativeFunction<Int Function()>>('getch')
  .asFunction<int Function()>();
final _clrtoeol = _libncurses
  .lookup<NativeFunction<Int Function()>>('clrtoeol')
  .asFunction<int Function()>();
final _move = _libncurses
  .lookup<NativeFunction<Int Function(Int, Int)>>('move')
  .asFunction<int Function(int, int)>();
//final _addch = _libncurses
//  .lookup<NativeFunction<Int Function(UnsignedInt)>>('addch')
//  .asFunction<int Function(int)>();
final _addstr = _libncurses
  .lookup<NativeFunction<Int Function(Charptr)>>('addstr')
  .asFunction<int Function(Charptr)>();
final _mvaddstr = _libncurses
  .lookup<NativeFunction<Int Function(Int, Int, Charptr)>>('mvaddstr')
  .asFunction<int Function(int, int, Charptr)>();
final _mvaddwstr = _libncurses
  .lookup<NativeFunction<Int Function(Int, Int, WCharptr)>>('mvaddwstr')
  .asFunction<int Function(int, int, WCharptr)>();

