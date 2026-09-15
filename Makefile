APP_NAME    := Debrowse
BUILD_DIR   := build
APP         := $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR ?= /Applications

.PHONY: all build run list install uninstall clean

all: build

build:
	./Scripts/build-app.sh

run: build
	open "$(APP)"

list: build
	"$(APP)/Contents/MacOS/$(APP_NAME)" --list

install: build
	-pkill -x $(APP_NAME) 2>/dev/null || true
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	ditto "$(APP)" "$(INSTALL_DIR)/$(APP_NAME).app"
	open "$(INSTALL_DIR)/$(APP_NAME).app"

uninstall:
	-pkill -x $(APP_NAME) 2>/dev/null || true
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"

clean:
	rm -rf "$(BUILD_DIR)" .build
