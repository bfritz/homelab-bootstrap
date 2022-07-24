rpi_snapcast_client_gen_usercfg() {
	cat <<-EOF
	gpu_mem=16
	dtparam=audio=on
	dtoverlay=hifiberry-dac
EOF
}

build_rpi_snapcast_client_usercfg() {
	rpi_snapcast_client_gen_usercfg > "${DESTDIR}"/usercfg.txt
}

section_rpi_snapcast_client_usercfg() {
	[ "$PROFILE" = "rpi_snapcast_client" ] || return 0
	build_section rpi_snapcast_client_usercfg "$( rpi_snapcast_client_gen_usercfg | checksum )"
}

profile_rpi_snapcast_client() {
	profile_rpi
	kernel_cmdline="console=tty1 $CMDLINE_EXTRA"
	apks="$apks
		chrony
		openssh-server
		prometheus-node-exporter
		wireless-tools
		wpa_supplicant
		atop
		snapcast
"
	apkovl="genapkovl-rpi-snapcast-client.sh"
}
