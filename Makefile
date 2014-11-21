LUVI_BIN=deps/luvit-up/luvi-binaries/$(shell uname -s)_$(shell uname -m)/luvi

all:
	LUVI_APP=app:deps/luvit-up/app LUVI_TARGET=luvit ${LUVI_BIN}

test:
	LUVI_ZIP=${LUVI_ZIP} deps/luvit-up/luvi-binaries/${PLATFORM}/luvi test

.PHONY: all
