#!/bin/sh -e

K0S_ARCH=amd64
K0S_VER=1.23.1+k0s.0
K0S_URL="https://github.com/k0sproject/k0s/releases/download/v$K0S_VER/k0s-v$K0S_VER-$K0S_ARCH"

hostname="$1"

basedir="$(dirname "$0")"
[ "$basedir" = "/bin" ] && basedir="./scripts" # shellspec workaround for $0 handling
. "$basedir"/shared.sh


configure_installed_packages() {
	apk_add \
		chrony \
		openssh-server \
		findutils \
		coreutils \
		curl \
		iptables \
		nfs-utils \

}

configure_network() {
	mkdir -p "$tmp"/etc/network
	makefile root:root 0644 "$tmp"/etc/network/interfaces <<EOF
# ifupdown-ng syntax
# See https://github.com/ifupdown-ng/ifupdown-ng

auto lo
iface lo
	use loopback

auto eth0
iface eth0
	use dhcp
EOF
}

configure_init_scripts() {
	rc_add devfs sysinit
	rc_add dmesg sysinit
	rc_add mdev sysinit
	rc_add hwdrivers sysinit
	rc_add modloop sysinit

	rc_add hwclock boot
	rc_add modules boot
	rc_add sysctl boot
	rc_add hostname boot
	rc_add bootmisc boot
	rc_add klogd boot
	rc_add syslog boot

	rc_add mount-ro shutdown
	rc_add killprocs shutdown
	rc_add savecache shutdown

	# additional services
	rc_add chronyd default
	rc_add sshd default
	rc_add cgroups default
}

install_k0s() {
	# install k0s
	[ -d "$tmp"/usr ] || mkdir --mode=0755 "$tmp"/usr
	[ -d "$tmp"/usr/local ] || mkdir --mode=0755 "$tmp"/usr/local
	[ -d "$tmp"/usr/local/bin ] || mkdir --mode=0755 "$tmp"/usr/local/bin

	echo "Downloading k0s from URL: $K0S_URL"
	curl -Lf# $K0S_URL > "$tmp"/usr/local/bin/k0s
	chmod 755 "$tmp"/usr/local/bin/k0s
}


tmp="$(mktemp -d)"
trap cleanup EXIT

mkdir --mode=0755 "$tmp"/etc
makefile root:root 0644 "$tmp"/etc/hostname <<EOF
k0s-worker
EOF

configure_network
configure_installed_packages
add_ssh_key
configure_init_scripts
install_k0s

tar -c -C "$tmp" etc root usr/local | gzip -9n > "$hostname".apkovl.tar.gz
