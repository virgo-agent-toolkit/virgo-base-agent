APP_FILES=$(shell find . tests -type f)

all: virgo

virgo: lit $(APP_FILES)
	./lit make

lit:
	curl -L https://github.com/luvit/lit/raw/0.9.7/web-install.sh | sh

clean:
	rm -rf virgo lit-* luvi lit

lint:
	find . tests -name "*.lua" | xargs luacheck

test: virgo
	./virgo tests/run.lua

.PHONY: clean lint
