APP_FILES=$(shell find app tests -type f)

virgo-base: lit $(APP_FILES)
	./lit make app

luvi-binaries:
	git clone --depth 1 https://github.com/luvit/luvi-binaries.git

lit-app:
	git clone --depth 1 https://github.com/luvit/lit.git lit-app

lit: luvi-binaries lit-app
	LUVI_APP=lit-app/app LUVI_TARGET=$@ luvi-binaries/$(shell uname -s)_$(shell uname -m)/luvi

clean:
	rm -rf virgo-base lit lit-app luvi-binaries

lint:
	find app tests -name "*.lua" | xargs luacheck

test: virgo-base
	./virgo-base tests/run.lua

.PHONY: clean lint 
