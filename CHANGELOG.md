## 0.1.53
- small cleanups and scripts' rearrangment, and added icon

## 0.1.52
- add head of manual page to github-readme and a runtime screenshot

## 0.1.51
- add widechar support into dcurses to display wchared hostnames in title (display mode)

## 0.1.50
- load libcurses only in display mode

## 0.1.49
- constrain keyaction line to "hints exit" if there's not enough space

## 0.1.48
- deb+snap packaging related

## 0.1.47
- add -f option (custom stat fields)

## 0.1.46
- add -w option (whois info: AS Country etc.)

## 0.1.45
- rm ppc64el from snap builds

## 0.1.44
- switch snap builds to flutter.dart and add arm64,ppc64el

## 0.1.43
- add snapcraft.yaml to build .snap package (successfully 'apt install dart' on amd64 only)

## 0.1.42
- add script for .deb package building

## 0.1.41
- add minimal manual page and Makefile
- fix ivalopt typo

## 0.1.40
- add 'interval' runtime customization
- runtime aux keys in uppercase (Pause, Reset, Quit, Help)
- add [spacebar] alias to [P]ause key, [x] to [Q]uit, [h] to [H]elp

## 0.1.39
- add -a option (address|interface for 'ping -I')
- keep options in lowercase until it's possible (Q -> q)

## 0.1.38
- add option string to json output

## 0.1.37
- add -p option (payload pattern)

## 0.1.36
- add 'count/cycles' runtime customization

## 0.1.35
- do not restart pings unless params have been changed (runtime customization)

## 0.1.34
- indicate runtime TTL customization

## 0.1.33
- add -Q option (QoS/ToS bits)

## 0.1.32
- add extra messaging if there's wrong data in replies

## 0.1.31
- add payload size customization at runtime

## 0.1.30
- add -s option (payload size)

## 0.1.29
- rearrange waitlist filling
- add more syslog messages

## 0.1.28
- add error indication at exit
- add IPvN options [-4 -6]
- change '-w timeout' to '-i interval' option name

## 0.1.27
- shell version-n-changelog generator

## 0.1.26
- better indication if something is firewalled

## 0.1.25
- keyaction timer not dependent on ping timeout

## 0.1.24
- customize TTL range at runtime

## 0.1.23
- put off macos support until 'Request timeout' timestamping could be found

## 0.1.22
- add macos timestamp (debug mode)

## 0.1.21
- workflow testrun

## 0.1.20
- add '-t' option (min,max TTL setting)

## 0.1.19
- add small internal ping wrapper (with timestamps, status, probes, additional error-printing)

## 0.1.18
- try to load curses library in different ways

## 0.1.17
- add output in JSON format (-j)

## 0.1.16
- add basic interactive key-actions

## 0.1.15
- add output header
- rearrange timer cancel

## 0.1.14
- hop addrname as a list

## 0.1.13
- less dependencies' constrains

## 0.1.12
- align a bit output data

## 0.1.11
- add minimal libncurses wrapper

## 0.1.10
- add std statdata
- align output a bit

## 0.1.9
- add basic ncurses mode

## 0.1.8
- use ping wrapper from a fork to not mixup with ping-wrapper from pubdev

## 0.1.7
- hop-data as an immutable record in order to keep its elements synced

## 0.1.6
- reorganize by files a bit

## 0.1.5
- support basic CLI arguments

## 0.1.4
- up to a simple report

## 0.1.3
- create Ping object per hop

## 0.1.2
- initial probe

## 0.1.1
- Initial commit
