rpi_basic_gen_usercfg() {
	cat <<-EOF
	gpu_mem=16
	dtoverlay=disable-bt
EOF
}

build_rpi_basic_usercfg() {
	rpi_basic_gen_usercfg > "${DESTDIR}"/usercfg.txt
}

section_rpi_basic_usercfg() {
	[ "$PROFILE" = "rpi_basic" ] || return 0
	build_section rpi_basic_usercfg "$( rpi_basic_gen_usercfg | checksum )"
}

profile_rpi_basic() {
	profile_rpi
	kernel_cmdline="console=tty1 console=ttyAMA0 $CMDLINE_EXTRA"
	apks="$apks
	    chrony
	    openssh-server
	    prometheus-node-exporter
	    atop
	    btop
"
	apkovl="genapkovl-rpi-basic.sh"
}
