CC=zig
CLN_PATH=

build:
	$(CC) build

fmt:
	$(CC) fmt src/*.zig

check:
	$(CLN_PATH) $(CC) test src/*.zig
