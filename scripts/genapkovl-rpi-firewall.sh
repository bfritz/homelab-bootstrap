#!/bin/sh -e

hostname="$1"

basedir="$(dirname "$0")"
[ "$basedir" = "/bin" ] && basedir="./scripts" # shellspec workaround for $0 handling
. "$basedir"/shared.sh

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
	vlan_id="$1"
	net_prefix="$2"
	cat >> "$tmp"/etc/network/interfaces <<EOF

auto eth0.$vlan_id
iface eth0.$vlan_id inet static
	address $net_prefix.1
	netmask 255.255.255.0
EOF
}

add_vlan_dns_and_dhcp() {
	vlan_id="$1"
	net_prefix="$2"
	vlan_name="$3"
	enable_dhcp="${4:-1}"
	file=$(printf "%03d_%s.conf" $((vlan_id * 10)) "$vlan_name")

	mkdir -p "$tmp"/etc/dnsmasq.d
	cat >> "$tmp/etc/dnsmasq.d/$file" <<EOF
interface=eth0.$vlan_id
bind-interfaces
EOF

	dhcp_range_option="dhcp-range=$net_prefix.0,static"
	if [ "$enable_dhcp" = "1" ]; then
		dhcp_range_option="dhcp-range=$net_prefix.100,$net_prefix.149,12h"
	fi

	cat >> "$tmp/etc/dnsmasq.d/$file" <<EOF

$dhcp_range_option

# use firewall as ntp server
dhcp-option=42,$net_prefix.1
EOF
}


configure_network() {
	mkdir -p "$tmp"/etc/network
	makefile root:root 0644 "$tmp"/etc/network/interfaces <<EOF
# ifupdown-ng syntax
# See https://github.com/ifupdown-ng/ifupdown-ng

auto lo
iface lo
	use loopback

auto eth0.110
iface eth0.110
	use dhcp
EOF

	add_vlan_interface 101 172.22.1  ; add_vlan_dns_and_dhcp 101 172.22.1  loc
	add_vlan_interface 102 172.22.2  ; add_vlan_dns_and_dhcp 102 172.22.2  dmz  0
	add_vlan_interface 103 172.22.3  ; add_vlan_dns_and_dhcp 103 172.22.3  swif
	add_vlan_interface 104 172.22.4  ; add_vlan_dns_and_dhcp 104 172.22.4  gwif
	add_vlan_interface 105 172.22.5  ; add_vlan_dns_and_dhcp 105 172.22.5  vwif
	add_vlan_interface 106 172.22.6  ; add_vlan_dns_and_dhcp 106 172.22.6  awif 0
	add_vlan_interface 111 172.22.11 ; add_vlan_dns_and_dhcp 111 172.22.11 ata  0
	add_vlan_interface 112 172.22.12 ; add_vlan_dns_and_dhcp 112 172.22.12 voip 0
	add_vlan_interface 113 172.22.13 ; add_vlan_dns_and_dhcp 113 172.22.13 mgmt 0
	add_vlan_interface 118 172.22.18 ; add_vlan_dns_and_dhcp 118 172.22.18 k8s  0
}

configure_chrony_as_server() {
	[ -d "$tmp"/etc/chrony ] || mkdir --mode=0755 "$tmp"/etc/chrony
	makefile root:root 0644 "$tmp"/etc/chrony/chrony.conf <<EOF
# default config
pool pool.ntp.org iburst
initstepslew 10 pool.ntp.org
driftfile /var/lib/chrony/chrony.drift
rtcsync
cmdport 0
# end default config

# run ntp server for internal networks
allow 172.22.0.0/19
EOF
}

configure_wireguard() {
	mkdir -p "$tmp"/etc/wireguard
	makefile root:root 0600 "$tmp"/etc/wireguard/wg0.conf.in <<EOF
[Interface]
PrivateKey={{ .vpn.wg0.private_key }}

[Peer]
PublicKey={{ .vpn.wg0.public_key }}
PresharedKey={{ .vpn.wg0.preshared_key }}
Endpoint={{ .vpn.ext_ip }}:{{ .vpn.port }}
PersistentKeepalive=25
AllowedIPs=0.0.0.0/0, ::/0
EOF

	makefile root:root 0600 "$tmp"/etc/network/interfaces.wg0.in <<EOF

auto wg0
iface wg0 inet static
	requires eth0.110
	use wireguard
	address {{ .vpn.int_ip }}
	netmask {{ .vpn.int_mask }}
	# send DNS traffic over VPN
	post-up ip -4 route add 1.1.1.1 dev wg0
	post-up ip -4 route add 8.8.8.8 dev wg0
	post-up ip -4 route add 8.8.4.4 dev wg0
	# route loc traffic over VPN
	post-up /usr/local/bin/vpn_routes add loc_net 101 "{{ .vpn.int_ip }}"
	pre-down /usr/local/bin/vpn_routes del loc_net 101
	# route dmz traffic over VPN
	post-up /usr/local/bin/vpn_routes add dmz_net 102 "{{ .vpn.int_ip }}"
	pre-down /usr/local/bin/vpn_routes del dmz_net 102
	# route vwifi traffic over VPN
	post-up /usr/local/bin/vpn_routes add vwif_net 105 "{{ .vpn.int_ip }}"
	pre-down /usr/local/bin/vpn_routes del vwif_net 105
	# route ATA traffic over VPN
	post-up /usr/local/bin/vpn_routes add ata_net 111 "{{ .vpn.int_ip }}"
	pre-down /usr/local/bin/vpn_routes del ata_net 111
	# route k8s traffic over VPN
	post-up /usr/local/bin/vpn_routes add k8s_net 118 "{{ .vpn.int_ip }}"
	pre-down /usr/local/bin/vpn_routes del k8s_net 118
	# honor routes to 172.22.x.0/24 networks; see https://stackoverflow.com/a/68988919
	post-up ip -4 rule add suppress_prefixlength 0 table main
	pre-down ip -4 rule del suppress_prefixlength 0 table main
EOF

	[ -d "$tmp"/usr ] || mkdir --mode=0755 "$tmp"/usr
	[ -d "$tmp"/usr/local ] || mkdir --mode=0755 "$tmp"/usr/local
	[ -d "$tmp"/usr/local/bin ] || mkdir --mode=0755 "$tmp"/usr/local/bin
	makefile root:root 0755 "$tmp"/usr/local/bin/vpn_routes <<EOF
#!/bin/sh

set -e

[ -z "\$VERBOSE" ] || set -x

add_route() {
	local table_name="\$1"
	local vlan_id="\$2"
	local source_ip="\$3"

	grep -q "\$table_name" /etc/iproute2/rt_tables || echo "\$vlan_id \$table_name" >> /etc/iproute2/rt_tables
	ip -4 rule add iif "eth0.\$vlan_id" table "\$table_name"
	ip -4 route add default via "\$source_ip" dev wg0 table "\$table_name"
}

del_route() {
	local table_name="\$1"
	local vlan_id="\$2"

	ip -4 route flush table "\$table_name" || true
	ip -4 rule del iif "eth0.\$vlan_id" table "\$table_name" || true
}

case "\$1" in
add)
	add_route "\$2" "\$3" "\$4"
	;;
del)
	del_route "\$2" "\$3"
	;;
esac
EOF
}

log_martians() {
	[ ! -d "$tmp"/etc ] && mkdir --mode=0755 "$tmp"/etc
	[ ! -d "$tmp"/etc/sysctl.d ] && mkdir --mode=0700 "$tmp"/etc/sysctl.d
	makefile root:root 0644 "$tmp"/etc/sysctl.d/log_martians.conf <<EOF
# https://www.cyberciti.biz/faq/linux-log-suspicious-martian-packets-un-routable-source-addresses/
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
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
	rc_add dnsmasq default
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

add_customize_image_init_scripts() {
	mkdir -p "$tmp"/etc/init.d
	makefile root:root 0755 "$tmp"/etc/init.d/customize_image <<EOF
#!/sbin/openrc-run

description="First boot image customization"

conf=/media/mmcblk0p1/config.yaml

depend() {
	before iptables ip6tables
}

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

	ebegin "Translating awall configuration into iptables rules"
	awall translate
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
	[ -e /root/.ssh/authorized_keys ] && lbu include /root/.ssh/authorized_keys
	[ -e /usr/local/bin/vpn_routes ] && lbu include /usr/local/bin/vpn_routes
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
log_martians
configure_installed_packages
configure_syslog
configure_chrony_as_server
add_ssh_key
configure_init_scripts
add_customize_image_init_scripts
install_overlays

echo "Creating overlay file $hostname.apkovl.tar.gz ..."
tar -C "$tmp" -c etc root usr/local | gzip -9n > "$hostname.apkovl.tar.gz"
