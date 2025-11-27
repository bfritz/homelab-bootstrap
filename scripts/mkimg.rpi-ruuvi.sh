rpi_ruuvi_gen_usercfg() {
	cat <<-EOF
	gpu_mem=16
EOF
}

build_rpi_ruuvi_usercfg() {
	rpi_ruuvi_gen_usercfg > "${DESTDIR}"/usercfg.txt
}

section_rpi_ruuvi_usercfg() {
	[ "$PROFILE" = "rpi_ruuvi" ] || return 0
	build_section rpi_ruuvi_usercfg "$( rpi_ruuvi_gen_usercfg | checksum )"
}

profile_rpi_ruuvi() {
	profile_rpi
	kernel_cmdline="console=tty1 $CMDLINE_EXTRA"
	apks="$apks
		chrony
		openssh-server
		prometheus-node-exporter
		wireless-tools
		wpa_supplicant
		atop
		btop
		bluez
		tmux
		pv
"
	apkovl="genapkovl-rpi-ruuvi.sh"
}
