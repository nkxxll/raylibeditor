ODIN := odin
PKG_CONFIG := pkg-config

PKGS := lua5.4
TARGET := app
SRC := .

.PHONY: build run clean

build:
	$(ODIN) build $(SRC) -out:$(TARGET) \
		-extra-linker-flags:"-L/opt/homebrew/opt/lua@5.4/lib -llua"

run: build
	./$(TARGET)

clean:
	rm -f $(TARGET)
