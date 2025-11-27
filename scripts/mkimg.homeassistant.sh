profile_homeassistant() {
	profile_standard
	title="Alpine for Home Assistant"
	desc="Standard Alpine image for running Home Assistant on amd64. Runs from RAM."
	arch="x86_64"
	apks="$apks
		chrony
		openssh-server
		prometheus-node-exporter
		wireless-tools
		wpa_supplicant
		atop
		btop
		bluez
		dbus
		git
		picocom
		restic
		socat
		tmux
		python3
		py3-packaging
		tzdata
		ffmpeg
		ffmpeg-libavformat
		libpcap
		libturbojpeg
		blas

"
	apkovl="genapkovl-homeassistant.sh"
}
