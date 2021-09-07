section_rpi_fw_config() {
    [ "$hostname" = "rpi-fw" ] || return 0
    build_section rpi_config $( (rpi_gen_cmdline ; rpi_gen_config) | checksum )
    build_section rpi_blobs
}

profile_rpi_firewall() {
	profile_rpi
	kernel_cmdline="console=tty1 $CMDLINE_EXTRA"
	apks="$apks awall dnsmasq iproute2 iptables ulogd-json ulogd-openrc vlan wireguard-tools-wg"
	apkovl="genapkovl-rpi-firewall.sh"
	hostname="rpi-fw"
}
