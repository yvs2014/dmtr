
import 'dart:io' show Platform;
import 'dart:ffi';
import 'package:ffi/ffi.dart';

final nilptr = nullptr;
typedef Voidptr = Pointer<Void>;
typedef Charptr = Pointer<Char>;
typedef Intptr = Pointer<Int>;

const cOK = 0;
const cERR = -1;
const cAttrShift = 8;
const aBold = 1 << (13 + cAttrShift);

List<String> get libNames => ['libncurses', 'libncursesw', 'libcurses'];

List<String> get soSuffixes {
  if (Platform.isLinux) return ['so.6', 'so'];
  if (Platform.isMacOS) return ['dylib'];
  if (Platform.isWindows) return ['dll'];
  return ['so'];
}

DynamicLibrary _dynload(List<String> names, List<String> suffixes) {
  List errs = [];
  for (var lib in names) {
    for (var so in suffixes) {
      try { return DynamicLibrary.open('$lib.$so'); }
      catch (e) { errs.add(e); }
    }
  }
  for (var e in errs) { print(e); }
  throw Exception("No one library can be loaded: ${names.join(', ')}");
}

final _libncurses = _dynload(libNames, soSuffixes);

// C functions' wrapping
Voidptr initscr() => _initscr();
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


// FFI bindings
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

