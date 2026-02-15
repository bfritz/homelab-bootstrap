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
		tmux \
		bluez \
		dbus \
		restic \
		python3 \
		py3-packaging \
		dbus \
		ffmpeg \
		ffmpeg-libavformat \
		libpcap \
		libturbojpeg \
		tzdata \

}

configure_network() {
	mkdir -p "$tmp"/etc/network
	makefile root:root 0644 "$tmp"/etc/network/interfaces <<EOF
# ifupdown-ng syntax
# See https://github.com/ifupdown-ng/ifupdown-ng

auto lo
iface lo
	use loopback

auto eth0
iface eth0
	use dhcp
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
}

_ha_install_in_venv() {
	version="$1"

	mkdir -p "$tmp"/srv
	# the --system-site-packages is so py3-netifaces is used and not rebuilt (fails to compile)
	python -m venv --system-site-packages "$tmp"/srv/homeassistant

	# Download the python package list and constraints
	mkdir -p "$tmp"/srv/homeassistant/build/homeassistant
	for F in requirements.txt requirements_all.txt homeassistant/package_constraints.txt; do
		curl -Lf# -o "$tmp"/srv/homeassistant/build/$F "https://raw.githubusercontent.com/home-assistant/core/refs/tags/$version/$F"
	done

	# Disable modules that fail to compile in our build environment.
	sed -i "s,^\(aiokafka\),# \1," "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(av\),# \1," "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(deebot-client\),# \1," "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(pytradfri\),# \1," "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(pyads\),# \1," "$tmp"/srv/homeassistant/build/requirements*.txt

	# Disable unused modules that bloat ramdisk.
	sed -i "s,^\(aioaquacell=\),# \1,"     "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(aiobotocore\),# \1,"      "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(apprise\),# \1,"          "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(azure\),# \1,"            "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(boto3\),# \1,"            "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(botocore\),# \1,"         "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(env-canada\),# \1,"       "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(gassist-text\),# \1,"     "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(gcal-sync\),# \1,"        "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(google\),# \1,"           "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(googleapiclient\),# \1,"  "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(gspread\),# \1,"          "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(gTTS\),# \1,"             "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(insteon-frontend\),# \1," "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(knx-frontend\),# \1,"     "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(nice-go\),# \1,"          "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(noaa-coops\),# \1,"       "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(openai\),# \1,"           "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(pandas\),# \1,"           "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(pyezviz\),# \1,"          "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(pyinsteon\),# \1,"        "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(pypypasser\),# \1,"       "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(selenium\),# \1,"         "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(starlink\),# \1,"         "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(Tami4EdgeAPI\),# \1,"     "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(telegram\),# \1,"         "$tmp"/srv/homeassistant/build/requirements*.txt
	sed -i "s,^\(twilio\),# \1,"           "$tmp"/srv/homeassistant/build/requirements*.txt

	# Upgrade pip and then install homeassistant and its packages.
	"$tmp"/srv/homeassistant/bin/python -m pip install --upgrade pip
	"$tmp"/srv/homeassistant/bin/pip install \
		--constraint  "$tmp"/srv/homeassistant/build/homeassistant/package_constraints.txt \
		--requirement "$tmp"/srv/homeassistant/build/requirements.txt \
		--requirement "$tmp"/srv/homeassistant/build/requirements_all.txt \
		homeassistant=="$version"

	# Drop the "$tmp" prefix from scripts in the virutalenv.
	sed -i "s,/tmp/tmp.[a-zA-Z]\+/srv,/srv," "$tmp"/srv/homeassistant/bin/[a-z]*

	# No custom components currently, but here's how we would install them if needed...
	mkdir -p "$tmp"/srv/homeassistant/custom_components/

	# Example to include custom integration
	# git -C /tmp clone https://github.com/a/b
	# git -C /tmp/b checkout aabbcc0123
	# cp -r /tmp/b/custom_components/whatever "$tmp"/srv/homeassistant/custom_components/
	# The custom components here will need to be copied into /data/homeassistant/custom_components/
	# on the persistent media before they are enabled.

	chown -R 206:206 "$tmp"/srv/homeassistant
}

_ha_add_init_script() {
	mkdir -p "$tmp"/etc/conf.d
	makefile root:root 0644 "$tmp"/etc/conf.d/homeassistant <<EOF
# Configuration for /etc/init.d/homeassistant

# Path to the configuration directory.
#cfdir="/data/homeassistant"

# homeassistant_args="--skip-pip-packages av"
homeassistant_args="--skip-pip"

# The user (and group) to run homeassistant (hass) as.
#command_user="homeassistant"

# Wait 10 seconds for shutdown before killing the process.
#retry="TERM/10/KILL/5"

# Number of milliseconds to wait after starting to check if the daemon is still
# running (used only with start-stop-daemon). Set to empty string to disable.
#start_wait=100

# Uncomment to run with process supervisor.
# supervisor="supervise-daemon"
EOF

	mkdir -p "$tmp"/etc/init.d
	makefile root:root 0755 "$tmp"/etc/init.d/homeassistant <<EOF
#!/sbin/openrc-run

name="homeassistant"

: \${command_user:="homeassistant"}
: \${cfgdir:="/data/homeassistant"}
: \${start_wait=100}  # milliseconds
: \${retry="TERM/10/KILL/5"}

command="/srv/homeassistant/bin/hass"
command_args="--config \$cfgdir \${command_args:-\$homeassistant_args}"
command_background="yes"
pidfile="/run/\$RC_SVCNAME.pid"

start_stop_daemon_args="--wait \$start_wait \$start_stop_daemon_args"
# The leading space is to avoid fallback to \$start_stop_daemon_args when this
# is empty (supervise-daemon doesn't support --wait).
supervise_daemon_args=" \$supervise_daemon_args"

depend() {
	need dev localmount
	use bluetooth
}
EOF
}

configure_homeassistant() {
	_ha_install_in_venv 2025.1.4
	_ha_add_init_script

	rc_add bluetooth default
	rc_add dbus default
	rc_add homeassistant default
}

add_bootstrap_ha_init_script() {
	mkdir -p "$tmp"/etc/init.d
	makefile root:root 0755 "$tmp"/etc/init.d/bootstrap_homeassistant <<EOF
#!/sbin/openrc-run

description="Setup system to run Home Assistant"

start() {
	ebegin "Adding homeassistant user"
	if ! grep -q "^homeassistant:" /etc/passwd; then
		addgroup -g 206 -S homeassistant \
			&& adduser -S -s /sbin/nologin -h /srv/homeassistant -G homeassistant -u 206 homeassistant \
			&& addgroup homeassistant dialout
	fi
	eend \$?

	ebegin "Mounting homeassistant data partition"
	ha_data_part="\$(blkid /dev/[hsv]d?? /dev/nvme?n?p? | sed -n '/LABEL=.ha_data/p' | awk -F: '{print \$1}' | sort | head -n1)"
	if [ -z "\$ha_data_part" ]; then
		eend 0 "no partitions labeled for homeassistant data"
		return 0
	fi

	einfo "Found homeassistant data partition at \$ha_data_part .  Mounting at /data ."
	mkdir -p /data
	modprobe ext4 || true
	mount "\$ha_data_part" /data
	eend \$?
}
EOF
	rc_add bootstrap_homeassistant boot
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

tmp="$(mktemp -d)"
trap cleanup EXIT

mkdir -p "$tmp"/etc
makefile root:root 0644 "$tmp"/etc/hostname <<EOF
rpi-ha
EOF

configure_network
set_hostname_with_udhcpc
configure_installed_packages
configure_homeassistant
configure_chrony_as_client
configure_syslog
add_ssh_key
configure_init_scripts
add_bootstrap_ha_init_script

echo "Creating overlay file $hostname.apkovl.tar.gz ..."
tar -C "$tmp" -c etc root srv | gzip -9n > "$hostname.apkovl.tar.gz"
