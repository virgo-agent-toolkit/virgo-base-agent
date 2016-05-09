APP_FILES=$(shell find . tests -type f)
LIT_VERSION=3.3.3

all: luvi-sigar $(APP_FILES)

luvi-sigar: lit
	./lit get-luvi -o luvi-sigar

lit:
	[ -x lit ] || curl -L https://github.com/luvit/lit/raw/${LIT_VERSION}/get-lit.sh | sh

clean:
	rm -rf lit luvi luvi-sigar

lint:
	find . ! -path './deps/**' ! -path './tests/**' -name '*.lua' | xargs luacheck

test: lit $(APP_FILES)
	./lit install
	./luvi-sigar . -m tests/run.lua

.PHONY: clean lint lit
