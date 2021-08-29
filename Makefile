ACI_REPO := https://github.com/alpinelinux/alpine-chroot-install.git
ACI_TAG := v0.13.0
APK_REPOS := https://dl-cdn.alpinelinux.org/alpine/v3.14/main https://dl-cdn.alpinelinux.org/alpine/v3.14/community
WORK_DIR := bootstrap


all: build-images

build-images: firewall

firewall: armv7-chroot

armv7-chroot: clone-aci
	sudo $(WORK_DIR)/aci/alpine-chroot-install -a armv7 -d $(abspath $(WORK_DIR)/armv7) -p busybox
	$(WORK_DIR)/armv7/enter-chroot uname -a
	$(WORK_DIR)/armv7/destroy --remove

clone-aci:
ifeq ($(wildcard $(WORK_DIR)/aci/.git),)
	git -c advice.detachedHead=false clone -b $(ACI_TAG) $(ACI_REPO) $(WORK_DIR)/aci
endif
