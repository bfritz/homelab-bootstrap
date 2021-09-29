ACI_REPO := https://github.com/alpinelinux/alpine-chroot-install.git
ACI_TAG := v0.13.0
ALPINE_VERSION := 3.14
APORTS_REPO := https://github.com/alpinelinux/aports.git
BUILD_USER := imagebuilder
WORK_DIR := bootstrap
SHELLSPEC_DIR := shellspec
SHELLSPEC_REPO := https://github.com/shellspec/shellspec.git
SHELLSPEC_TAG := 0.28.1


all: build-images

lint:
	shellcheck scripts/*.sh

test: $(SHELLSPEC_DIR)/shellspec
	$(SHELLSPEC_DIR)/shellspec

clean:
ifneq ($(wildcard $(WORK_DIR)/armv7),)
	$(WORK_DIR)/armv7/destroy --remove
endif
	rm -rf $(WORK_DIR)

build-images: rpi-firewall rpi-basic

rpi-basic: armv7-chroot armv7-build-user # armv7-chroot-initramfs-hack
	$(WORK_DIR)/armv7/enter-chroot -u $(BUILD_USER) \
		$(abspath $(WORK_DIR))/shared/aports/scripts/mkimage.sh \
		--arch armv7 \
		--profile rpi_basic \
		--outdir $(abspath $(WORK_DIR))/shared \
		--repository https://dl-cdn.alpinelinux.org/alpine/v$(ALPINE_VERSION)/main \
		--extra-repository https://dl-cdn.alpinelinux.org/alpine/v$(ALPINE_VERSION)/community
	$(WORK_DIR)/armv7/destroy --remove

rpi-firewall: armv7-chroot armv7-build-user # armv7-chroot-initramfs-hack
	HL_OVERLAY_DIR=$(abspath $(WORK_DIR))/shared/overlays \
	$(WORK_DIR)/armv7/enter-chroot -u $(BUILD_USER) \
		$(abspath $(WORK_DIR))/shared/aports/scripts/mkimage.sh \
		--arch armv7 \
		--profile rpi_firewall \
		--outdir $(abspath $(WORK_DIR))/shared \
		--repository https://dl-cdn.alpinelinux.org/alpine/v$(ALPINE_VERSION)/main \
		--extra-repository https://dl-cdn.alpinelinux.org/alpine/v$(ALPINE_VERSION)/community
	$(WORK_DIR)/armv7/destroy --remove

armv7-chroot: clone-aci populate-shared
	sudo SUDO_USER=$(BUILD_USER) \
		$(WORK_DIR)/aci/alpine-chroot-install \
		-a armv7 \
		-d $(abspath $(WORK_DIR))/armv7 \
		-i $(abspath $(WORK_DIR))/shared \
		-k "ARCH CI QEMU_EMULATOR HL_.*" \
		-p "abuild apk-tools alpine-conf busybox fakeroot sudo squashfs-tools mkinitfs"

armv7-build-user: armv7-chroot
	# add non-root user to build images
	$(WORK_DIR)/armv7/enter-chroot adduser $(BUILD_USER) abuild
	$(WORK_DIR)/armv7/enter-chroot adduser $(BUILD_USER) wheel # for sudo

ifeq ($(wildcard $(WORK_DIR)/shared/keys/*rsa),)
	rm -rf $(WORK_DIR)/shared/keys
	$(WORK_DIR)/armv7/enter-chroot -u $(BUILD_USER) \
		abuild-keygen -a -i -n
	$(WORK_DIR)/armv7/enter-chroot \
		chgrp abuild $(abspath $(WORK_DIR))/shared
	$(WORK_DIR)/armv7/enter-chroot \
		chmod g+rwx  $(abspath $(WORK_DIR))/shared
	$(WORK_DIR)/armv7/enter-chroot -u $(BUILD_USER) \
		cp -ar /home/$(BUILD_USER)/.abuild $(abspath $(WORK_DIR))/shared/keys
else
	$(WORK_DIR)/armv7/enter-chroot -u $(BUILD_USER) \
		cp -ar $(abspath $(WORK_DIR))/shared/keys /home/$(BUILD_USER)/.abuild
endif

populate-shared: clone-aports
	cp -pu scripts/* $(WORK_DIR)/shared/aports/scripts

clone-aci:
ifeq ($(wildcard $(WORK_DIR)/aci/.git),)
	git -c advice.detachedHead=false clone -b $(ACI_TAG) $(ACI_REPO) $(WORK_DIR)/aci
endif

clone-aports:
ifeq ($(wildcard $(WORK_DIR)/shared/aports/.git),)
	git clone --depth 1 $(APORTS_REPO) $(WORK_DIR)/shared/aports
endif

$(SHELLSPEC_DIR)/shellspec:
	git -c advice.detachedHead=false clone --depth 1 -b $(SHELLSPEC_TAG) $(SHELLSPEC_REPO) $(SHELLSPEC_DIR)

# Insert `--allow-untrusted` into the init script used to boostrap the live system
# from the initramfs.  Useful for debugging errors...like why `/etc/inittab` is missing.
# (See previous commits.)
armv7-chroot-initramfs-hack:
	$(WORK_DIR)/armv7/enter-chroot \
		sed -i 's/^apkflags="\(.*\)"/apkflages="--allow-untrusted \1"/' /usr/share/mkinitfs/initramfs-init
	$(WORK_DIR)/armv7/enter-chroot \
		grep '^apk' /usr/share/mkinitfs/initramfs-init

.PHONY: lint
