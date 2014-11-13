LUVI_ZIP=app.zip

all:
	contrib/zip.py ${LUVI_ZIP} deps/luvit-up/app app

test:
	LUVI_ZIP=${LUVI_ZIP} deps/luvit-up/luvi-binaries/Darwin_x86_64/luvi

.PHONY: all
