LUVI_ZIP=app.zip

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
	PLATFORM=Linux_x86_64
endif
ifeq ($(UNAME_S),Darwin)
	PLATFORM=Darwin_x86_64
endif

all:
	contrib/zip.py ${LUVI_ZIP} deps/luvit-up/app app

test:
	LUVI_ZIP=${LUVI_ZIP} deps/luvit-up/luvi-binaries/${PLATFORM}/luvi

.PHONY: all
