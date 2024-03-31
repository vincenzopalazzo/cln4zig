CC=zig

build:
	$(CC) build

fmt:
	$(CC) fmt src/**/*.zig
	$(CC) fmt src/*.zig

check:
	$(CC) build test --summary all
