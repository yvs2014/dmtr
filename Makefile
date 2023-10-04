
NAME = dmtr
PREFIX ?= /usr/local
BASEDIR = $(DESTDIR)$(PREFIX)
MANDIR ?= $(BASEDIR)/share/man/man1

$(NAME): deps
	dart pub get
	dart compile exe -o $@ bin/$@.dart

install: $(NAME)
	@mkdir -p $(BASEDIR)/bin
	install -m 755 $(NAME) $(BASEDIR)/bin
	@mkdir -p $(MANDIR)
	install -m 644 $(NAME).1 $(MANDIR)/
	gzip -f $(MANDIR)/$(NAME).1

uninstall:
	rm $(BASEDIR)/bin/$(NAME) $(MANDIR)/$(NAME).1.gz

clean:
	rm -f $(NAME)

deps:
	command -v dart >/dev/null || (sudo apt install -y dart || ./misc/apt_install_dart.sh)
	dart --version

.PHONY: clean

