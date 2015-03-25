APP_FILES=$(shell find . tests -type f)

all: lit $(APP_FILES)

lit:
	[ -x lit ] || curl -L https://github.com/luvit/lit/raw/1.0.2/get-lit.sh | sh

clean:
	rm -rf lit

lint:
	find . tests -name "*.lua" | xargs luacheck

test: lit $(APP_FILES)
	./lit install
	LUVI_APP=. LUVI_MAIN=tests/main.lua ./lit

.PHONY: clean lint lit
