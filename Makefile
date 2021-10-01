export ACI_REPO := https://github.com/alpinelinux/alpine-chroot-install.git
export ACI_TAG := v0.13.0
export ALPINE_VERSION := 3.14
export APORTS_REPO := https://github.com/alpinelinux/aports.git
export BUILD_USER := imagebuilder
export WORK_DIR := bootstrap

SHELLSPEC_DIR := shellspec
SHELLSPEC_REPO := https://github.com/shellspec/shellspec.git
SHELLSPEC_TAG := 0.28.1

.PHONY: all build-images rpi-basic rpi-firewall k0s-worker lint test clean

all: build-images

build-images: rpi-basic rpi-firewall k0s-worker

rpi-basic:
	ARCH=armv7  make -f Makefile.images rpi-basic

rpi-firewall:
	ARCH=armv7  make -f Makefile.images rpi-firewall

k0s-worker:
	ARCH=x86_64 make -f Makefile.images k0s-worker

lint:
	shellcheck --exclude=SC1090,SC1091 scripts/shared.sh scripts/genapkovl-*.sh

test: $(SHELLSPEC_DIR)/shellspec
	$(SHELLSPEC_DIR)/shellspec

$(SHELLSPEC_DIR)/shellspec:
	git -c advice.detachedHead=false clone --depth 1 -b $(SHELLSPEC_TAG) $(SHELLSPEC_REPO) $(SHELLSPEC_DIR)

clean:
	ARCH=armv7  make -f Makefile.images clean
	ARCH=x86_64 make -f Makefile.images clean
