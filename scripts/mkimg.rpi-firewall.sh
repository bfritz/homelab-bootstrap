rpi_firewall_gen_usercfg() {
	cat <<-EOF
	gpu_mem=16
	dtoverlay=disable-bt
EOF
}

build_rpi_firewall_usercfg() {
	rpi_firewall_gen_usercfg > "${DESTDIR}"/usercfg.txt
}

section_rpi_firewall_usercfg() {
	[ "$PROFILE" = "rpi_firewall" ] || return 0
	build_section rpi_firewall_usercfg "$( rpi_firewall_gen_usercfg | checksum )"
}

profile_rpi_firewall() {
	profile_rpi
	kernel_cmdline="console=tty1 console=ttyAMA0 $CMDLINE_EXTRA"
	apks="$apks chrony openssh-server prometheus-node-exporter awall dnsmasq iproute2 iptables ulogd-json ulogd-openrc wireguard-tools-wg"
	apkovl="genapkovl-rpi-firewall.sh"
}
