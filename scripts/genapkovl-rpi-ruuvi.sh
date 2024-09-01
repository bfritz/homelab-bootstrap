#!/bin/sh -e

RT_LISTENER_URL="https://fewerhassles.com/misc/${ARCH:-armhf}/ruuvitag-listener"

hostname="$1"

basedir="$(dirname "$0")"
[ "$basedir" = "/bin" ] && basedir="./scripts" # shellspec workaround for $0 handling
. "$basedir"/shared.sh

configure_installed_packages() {
	apk_add \
		chrony \
		openssh-server \
		prometheus-node-exporter \
		bluez \

}

configure_network() {
	mkdir -p "$tmp"/etc/network
	makefile root:root 0644 "$tmp"/etc/network/interfaces <<EOF
# ifupdown-ng syntax
# See https://github.com/ifupdown-ng/ifupdown-ng

auto lo
iface lo
	use loopback

auto wlan0
iface wlan0
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
	rc_add node-exporter default
}

install_ruuvitag_listener() {
       [ -d "$tmp"/usr ] || mkdir --mode=0755 "$tmp"/usr
       [ -d "$tmp"/usr/local ] || mkdir --mode=0755 "$tmp"/usr/local
       [ -d "$tmp"/usr/local/bin ] || mkdir --mode=0755 "$tmp"/usr/local/bin

       echo "Downloading ruuvitag-listener from URL: $RT_LISTENER_URL"
       curl -Lf# "$RT_LISTENER_URL" > "$tmp"/usr/local/bin/ruuvitag-listener
       chmod 755 "$tmp"/usr/local/bin/ruuvitag-listener
}

configure_syslog() {
	mkdir -p "$tmp"/etc/conf.d
	makefile root:root 0644 "$tmp"/etc/conf.d/syslog <<EOF
# -t         Strip client-generated timestamps
# -s SIZE    Max size (KB) before rotation (default 200KB, 0=off)
# -b N       N rotated logs to keep (default 1, max 99, 0=purge)

SYSLOGD_OPTS="-t -s 512 -b 10"
EOF
}

tmp="$(mktemp -d)"
trap cleanup EXIT

mkdir -p "$tmp"/etc
makefile root:root 0644 "$tmp"/etc/hostname <<EOF
rpi-ruuvi
EOF

configure_network
configure_wifi
set_hostname_with_udhcpc
configure_installed_packages
configure_chrony_as_client
configure_syslog
add_ssh_key
configure_init_scripts
install_ruuvitag_listener
install_overlays

echo "Creating overlay file $hostname.apkovl.tar.gz ..."
tar -C "$tmp" -c etc root usr/local | gzip -9n > "$hostname.apkovl.tar.gz"
