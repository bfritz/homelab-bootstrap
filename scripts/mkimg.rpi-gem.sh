rpi_gem_gen_usercfg() {
	cat <<-EOF
	gpu_mem=16
EOF
}

build_rpi_gem_usercfg() {
	rpi_gem_gen_usercfg > "${DESTDIR}"/usercfg.txt
}

section_rpi_gem_usercfg() {
	[ "$PROFILE" = "rpi_gem" ] || return 0
	build_section rpi_gem_usercfg "$( rpi_gem_gen_usercfg | checksum )"
}

profile_rpi_gem() {
	profile_rpi
	kernel_cmdline="console=tty1 $CMDLINE_EXTRA"
	apks="$apks
		chrony
		openssh-server
		prometheus-node-exporter
		wireless-tools
		wpa_supplicant
		atop
		tmux
"
	apkovl="genapkovl-rpi-gem.sh"
}
