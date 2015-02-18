APP_FILES=$(shell find . tests -type f)
LUVI_URL=https://raw.githubusercontent.com/luvit/luvi-binaries/master/`uname -s`_`uname -m`/luvi
LIT_ZIP=https://codeload.github.com/luvit/lit/tar.gz/cleanup

all: virgo

virgo: lit $(APP_FILES)
	LUVI_APP=lit-cleanup ./luvi make

lit:
	curl $(LIT_ZIP) | tar -xzv
	curl $(LUVI_URL) > luvi && chmod +x luvi
	LUVI_APP=lit-cleanup ./luvi make lit-cleanup

clean:
	rm -rf virgo lit-cleanup lit luvi

lint:
	find . tests -name "*.lua" | xargs luacheck

test: virgo
	./virgo tests/run.lua

.PHONY: clean lint
