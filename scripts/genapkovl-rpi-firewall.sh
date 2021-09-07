#!/bin/sh -e

hostname="$1"

source "$(dirname "$0")/shared.sh"

add_ssh_key() {
	mkdir -p --mode=700 "$tmp"/root
	if [ -n "$HL_SSH_KEY_URL" ]; then
		mkdir -p "$tmp"/root/.ssh
		chmod 700 "$tmp"/root/.ssh

		curl -o "$tmp"/root/.ssh/authorized_keys "$HL_SSH_KEY_URL"
		chmod 400 "$tmp"/root/.ssh/authorized_keys
	fi
}

configure_installed_packages() {
	mkdir -p "$tmp"/etc/apk
	makefile root:root 0644 "$tmp"/etc/apk/world <<EOF
alpine-base
awall
dnsmasq
iproute2
iptables
openssh-server
wireguard-tools-wg
ulogd-json
ulogd-openrc
vlan
EOF
}

add_vlan_interface() {
	VLAN_ID="$1"
	cat >> "$tmp"/etc/network/interfaces <<EOF

auto eth0.$VLAN_ID
iface eth0.$VLAN_ID inet static
	address 172.22.$VLAN_ID.1
	netmask 255.255.255.0
EOF
}

add_vlan_dns_and_dhcp() {
	VLAN_ID="$1"
	VLAN_NAME="$2"
	FILE=$(printf "%03d_%s.conf" $((VLAN_ID * 10)) "$VLAN_NAME")
	mkdir -p "$tmp"/etc/dnsmasq.d
	cat >> "$tmp/etc/dnsmasq.d/$FILE" <<EOF
interface=eth0.$VLAN_ID
bind-interfaces
EOF

if [ "$VLAN_NAME" != "mgmt" ] && [ "$VLAN_NAME" != "k8s" ]; then
	cat >> "$tmp/etc/dnsmasq.d/$FILE" <<EOF

dhcp-range=172.22.$VLAN_ID.100,172.22.$VLAN_ID.149,12h
EOF
fi
}


add_vlan() {
	VLAN_ID="$1"
	VLAN_NAME="$2"
	add_vlan_interface "$VLAN_ID"
	add_vlan_dns_and_dhcp "$VLAN_ID" "$VLAN_NAME"
}

configure_network() {
	mkdir -p "$tmp"/etc/network
	makefile root:root 0644 "$tmp"/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0.10
iface eth0.10 inet dhcp
EOF

	add_vlan 1 loc
	add_vlan 2 dmz
	add_vlan 3 swif
	add_vlan 4 gwif
	add_vlan 13 mgmt
	add_vlan 18 k8s
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
	rc_add awall default
	rc_add dnsmasq default
}

tmp="$(mktemp -d)"
trap cleanup EXIT

mkdir -p "$tmp"/etc
makefile root:root 0644 "$tmp"/etc/hostname <<EOF
$hostname
EOF

configure_network
configure_installed_packages
add_ssh_key
configure_init_scripts

tar -C "$tmp" -c etc root | gzip -9n > "$hostname.apkovl.tar.gz"
