# Makefile for boardgame-org

EMACS ?= emacs
BATCH ?= $(EMACS) -batch
LOAD ?= -l $(shell pwd)/boardgame-org.el

EL_FILES = boardgame-org.el
ORG_FILES = boardgame-org.md boardgame-org-interface.md README.org

.PHONY: all clean compile test check-deps

all: compile

check-deps:
	@which $(EMACS) > /dev/null || (echo "Emacs not found"; exit 1)

compile: check-deps
	@echo "Compiling boardgame-org..."
	$(BATCH) -l package.el \
		--eval "(package-initialize)" \
		--eval "(byte-compile-file \"boardgame-org.el\")"

test: check-deps compile
	@echo "Running tests..."
	$(BATCH) -lERT \
		--eval "(let ((ert-test-files (list \"test-boardgame-org.el\"))) (ert-run-tests-batch))"

clean:
	rm -f *.elc
	rm -f *~ \#*\#

install:
	install -d $(DESTDIR)/$(EMACS)/site-lisp
	install -m 644 boardgame-org.el $(DESTDIR)/$(EMACS)/site-lisp/
