
NAME = dmtr
PREFIX ?= /usr/local
BASEDIR = $(DESTDIR)$(PREFIX)
MANDIR ?= $(BASEDIR)/share/man/man1

$(NAME):
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
	dpkg -s dart >/dev/null 2>&1 || (apt install -y dart || ./apt_install_dart.sh)
	dart pub get

.PHONY: clean

