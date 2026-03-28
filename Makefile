VPATH := @vlib:/Users/gumpy/repo
BIN   := vsqlite

.PHONY: build test clean

build:
	v -path "$(VPATH)" -o $(BIN) cmd/

test:
	v -path "$(VPATH)" test cmd/

clean:
	rm -f $(BIN)
