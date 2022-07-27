CC=zig

build:
	$(CC) build

fmt:
	$(CC) fmt src/*.zig

check:
	$(CC) test src/*.zig
