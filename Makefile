APP_FILES=$(shell find app -type f)
TEST_FILES=$(shell find tests -type f)
LUVIT_APP_FILES=$(shell find deps/luvit-up/app -type f)

LUVI_BIN=deps/luvit-up/luvi-binaries/$(shell uname -s)_$(shell uname -m)/luvi
LUVI_TARGET=base
LUVI_APP=tests:app:deps/luvit-up/app

all: $(LUVI_TARGET)

$(LUVI_TARGET): $(APP_FILES) $(LUVIT_APP_FILES) $(TEST_FILES)
	LUVI_APP=${LUVI_APP} LUVI_TARGET=${LUVI_TARGET} ${LUVI_BIN}

test: $(LUVIT_TARGET)
	./${LUVI_TARGET} test

clean:
	rm -f $(LUVI_TARGET)

.PHONY: all
