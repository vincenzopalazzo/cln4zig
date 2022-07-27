#!/bin/bash
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
zig version
./run-bitcoin.sh
cd code || exit 1
make
cd .. || exit 1
./run-clightning.sh
cd code || exit 1
ls -la
CLN_PATH=/workdir/lightning_dir_one/regtest/lightning-rpc make check