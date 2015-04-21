APP_FILES=$(shell find . tests -type f)
LIT_VERSION=1.1.4

all: lit $(APP_FILES)

lit:
	[ -x lit ] || curl -L https://github.com/luvit/lit/raw/${LIT_VERSION}/get-lit.sh | sh

clean:
	rm -rf lit luvi

lint:
	find . tests -name "*.lua" | xargs luacheck

test: lit $(APP_FILES)
	./lit install
	./luvi . -m tests/run.lua

.PHONY: clean lint lit
