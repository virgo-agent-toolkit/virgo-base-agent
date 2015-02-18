APP_FILES=$(shell find . tests -type f)
LIT=lit

virgo-base: $(APP_FILES)
	$(LIT) make

clean:
	rm -rf virgo-base

lint:
	find . tests -name "*.lua" | xargs luacheck

test: virgo-base
	./virgo-base tests/run.lua

.PHONY: clean lint 
