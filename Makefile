LUVI_BIN=deps/luvit-up/luvi-binaries/$(shell uname -s)_$(shell uname -m)/luvi
LUVI_TARGET=virgo-base

all:
	LUVI_APP=app:deps/luvit-up/app LUVI_TARGET=${LUVI_TARGET} ${LUVI_BIN}

test:
	${LUVIT_TARGET} test

.PHONY: all
