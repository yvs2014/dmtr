NAME = dmtr
DC   = dart
PREFIX ?= /usr
SHARE  != [ -d $(PREFIX)/share/man ] && echo /share || true
MANDIR ?= $(PREFIX)$(SHARE)/man/man1

$(NAME):
	$(DC) compile exe -o $@ bin/$@.dart

install: $(NAME)
	install -m 755 $(NAME) $(PREFIX)/bin
	@mkdir -p $(MANDIR)
	install -m 644 $(NAME).1 $(MANDIR)/
	gzip -f $(MANDIR)/$(NAME).1

.PHONY: clean

clean:
	rm -f $(NAME)

