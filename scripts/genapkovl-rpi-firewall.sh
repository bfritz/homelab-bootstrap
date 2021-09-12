#!/bin/sh -e

hostname="$1"

source "$(dirname "$0")/shared.sh"

add_ssh_key() {
	[ -d "$tmp"/root ] || mkdir --mode=0700 "$tmp"/root
	if [ -n "$HL_SSH_KEY_URL" ]; then
		mkdir --mode=0700 "$tmp"/root/.ssh

		curl -o "$tmp"/root/.ssh/authorized_keys "$HL_SSH_KEY_URL"
		chmod 0400 "$tmp"/root/.ssh/authorized_keys
	fi
}

configure_installed_packages() {
	apk_add \
		chrony \
		openssh-server \
		prometheus-node-exporter \
		awall \
		dnsmasq \
		iproute2 \
		iptables \
		wireguard-tools-wg \
		ulogd-json \
		ulogd-openrc \
		gomplate \

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
	vlan_id="$1"
	vlan_name="$2"
	enable_dhcp="${3:-1}"
	file=$(printf "%03d_%s.conf" $((vlan_id * 10)) "$vlan_name")

	mkdir -p "$tmp"/etc/dnsmasq.d
	cat >> "$tmp/etc/dnsmasq.d/$file" <<EOF
interface=eth0.$vlan_id
bind-interfaces
EOF

if [ "$enable_dhcp" = "1" ]; then
	cat >> "$tmp/etc/dnsmasq.d/$file" <<EOF

dhcp-range=172.22.$vlan_id.100,172.22.$vlan_id.149,12h
EOF
fi
}


configure_network() {
	mkdir -p "$tmp"/etc/network
	makefile root:root 0644 "$tmp"/etc/network/interfaces <<EOF
# ifupdown-ng syntax
# See https://github.com/ifupdown-ng/ifupdown-ng

auto lo
iface lo
	use loopback

auto eth0.10
iface eth0.10
	use dhcp
EOF

	add_vlan_interface  1 ; add_vlan_dns_and_dhcp  1 loc
	add_vlan_interface  2 ; add_vlan_dns_and_dhcp  2 dmz 0
	add_vlan_interface  3 ; add_vlan_dns_and_dhcp  3 swif
	add_vlan_interface  4 ; add_vlan_dns_and_dhcp  4 gwif
	add_vlan_interface 13 ; add_vlan_dns_and_dhcp 13 mgmt 0
	add_vlan_interface 18 ; add_vlan_dns_and_dhcp 18 k8s 0
}

configure_wireguard() {
	mkdir -p "$tmp"/etc/wireguard
	makefile root:root 0600 "$tmp"/etc/wireguard/wg0.conf.in <<EOF
[Interface]
PrivateKey={{ .vpn.wg0.private_key }}

[Peer]
PublicKey={{ .vpn.wg0.public_key }}
PresharedKey={{ .vpn.wg0.preshared_key }}
Endpoint={{ .vpn.ext_ip }}:51820
PersistentKeepalive=25
AllowedIPs=0.0.0.0/0, ::/0
EOF

	makefile root:root 0600 "$tmp"/etc/network/interfaces.wg0.in <<EOF

auto wg0
iface wg0 inet static
	requires eth0.10
	use wireguard
	address {{ .vpn.int_ip }}
	netmask {{ .vpn.int_mask }}
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
	rc_add awall default
	rc_add dnsmasq default
}

add_customize_image_init_scripts() {
	mkdir -p "$tmp"/etc/init.d
	makefile root:root 0755 "$tmp"/etc/init.d/customize_image <<EOF
#!/sbin/openrc-run

description="First boot image customization"

conf=/media/mmcblk0p1/config.yaml

start() {
	ebegin "Check if config present and template expansion possible"
	if [ ! -e "\$conf" ]; then
		eend 1 "template values not present at \$conf"
		return 1
	fi
	if ! command -v gomplate > /dev/null; then
		eend 1 "gomplate command is missing"
		return 1
	fi
	eend 0

	ebegin "Expanding wireguard templates"
	gomplate -c .="\$conf" -f /etc/wireguard/wg0.conf.in > /etc/wireguard/wg0.conf \
		&& rm /etc/wireguard/wg0.conf.in

	gomplate -c .="\$conf" -f /etc/network/interfaces.wg0.in >> /etc/network/interfaces \
		&& rm /etc/network/interfaces.wg0.in
	eend \$?

	ebegin "Deleting \$conf"
	mount -o remount,rw "\$(dirname \$conf)"
        rm \$conf
	eend \$?
	mount -o remount,ro "\$(dirname \$conf)"
}
EOF
	rc_add customize_image boot

	makefile root:root 0755 "$tmp"/etc/init.d/customize_image_save <<EOF
#!/sbin/openrc-run

description="First boot image customization - save with lbu commit"

depend() {
	# prefer to wait until sshd is running to backup host keys
	use sshd
}

start() {
	ebegin "Saving updates"
	rc-update del customize_image boot
	rc-update del customize_image_save default
	lbu commit -d mmcblk0p1
	eend $?
}
EOF
	rc_add customize_image_save default
}

tmp="$(mktemp -d)"
trap cleanup EXIT

mkdir -p "$tmp"/etc
makefile root:root 0644 "$tmp"/etc/hostname <<EOF
rpi-fw
EOF

configure_network
configure_wireguard
configure_installed_packages
add_ssh_key
configure_init_scripts
add_customize_image_init_scripts
install_overlays

echo "Creating overlay file $hostname.apkovl.tar.gz ..."
tar -C "$tmp" -c etc root | gzip -9n > "$hostname.apkovl.tar.gz"
