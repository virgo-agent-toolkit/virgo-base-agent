APP_FILES=$(shell find app -type f)
LUVIT_APP_FILES=$(shell find deps/luvit-up/app -type f)

LUVI_BIN=deps/luvit-up/luvi-binaries/$(shell uname -s)_$(shell uname -m)/luvi
LUVI_TARGET=virgo-base
LUVI_APP=app:deps/luvit-up/app

all: $(LUVI_TARGET)

$(LUVI_TARGET): $(APP_FILE) $(LUVIT_APP_FILES)
	LUVI_APP=${LUVI_APP} LUVI_TARGET=${LUVI_TARGET} ${LUVI_BIN}

test: $(LUVI_TARGET)
	./${LUVI_TARGET} test

clean:
	rm -f $(LUVI_TARGET)

.PHONY: all
