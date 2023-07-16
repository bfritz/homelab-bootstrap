#!/bin/sh -e

_err() {
    echo "$@" 1>&2
}

cleanup() {
        rm -rf "$tmp"
}

makefile() {
        OWNER="$1"
        PERMS="$2"
        FILENAME="$3"
        cat > "$FILENAME"
        chown "$OWNER" "$FILENAME"
        chmod "$PERMS" "$FILENAME"
}

rc_add() {
        mkdir -p "$tmp"/etc/runlevels/"$2"
        ln -sf /etc/init.d/"$1" "$tmp"/etc/runlevels/"$2"/"$1"
}

apk_add() {
        if [ ! -d "$tmp"/etc/apk ] ; then
                mkdir -p "$tmp"/etc/apk
        fi
        if [ ! -f "$tmp"/etc/apk/world ] ; then
                makefile root:root 0644 "$tmp"/etc/apk/world <<EOF
EOF
        fi
        for a in "$@" ; do
                if ! grep -q "$a" "$tmp"/etc/apk/world ; then
                        echo "$a" >> "$tmp"/etc/apk/world
                fi
        done
}

# if $HL_SSH_KEY_URL is set, download and drop into /root/.ssh/authorized_keys
add_ssh_key() {
    [ -d "$tmp"/root ] || mkdir --mode=0700 "$tmp"/root
    if [ -n "$HL_SSH_KEY_URL" ]; then
        mkdir --mode=0700 "$tmp"/root/.ssh

        curl --max-time 10 "$HL_SSH_KEY_URL" > "$tmp"/root/.ssh/authorized_keys
        chmod 0400 "$tmp"/root/.ssh/authorized_keys
    fi
}

add_vector() {
    version="$1"
    target="$2"
    dl_url="https://packages.timber.io/vector/$version/vector-$version-$target.tar.gz"

    [ -d "$tmp"/usr ] || mkdir --mode=0755 "$tmp"/usr
    [ -d "$tmp"/usr/local ] || mkdir --mode=0755 "$tmp"/usr/local
    [ -d "$tmp"/usr/local/bin ] || mkdir --mode=0755 "$tmp"/usr/local/bin

    dl_loc="$(mktemp -d)"
    echo "Downloading vector from URL: $dl_url"
    curl -Lf# --max-time 10 "$dl_url" > "$dl_loc"/vector.tar.gz
    tmpdir=$(mktemp -d)
    tar -C "$tmpdir" --strip-components 2 -xzf "$dl_loc"/vector.tar.gz
    mv "$tmpdir"/bin/vector "$tmp"/usr/local/bin/vector
    chmod 0755 "$tmp"/usr/local/bin/vector
    rm -rf "$tmpdir"

    [ -d "$tmp"/etc ] || mkdir --mode=0755 "$tmp"/etc
    [ -d "$tmp"/etc/conf.d ] || mkdir --mode=0755 "$tmp"/etc/conf.d
    [ -d "$tmp"/etc/init.d ] || mkdir --mode=0755 "$tmp"/etc/init.d

    makefile root:root 0644 "$tmp"/etc/conf.d/vector <<EOF
# See https://vector.dev/docs/reference/cli/

vector_opts="--config /etc/vector/vector.toml"
EOF

    makefile root:root 0755 "$tmp"/etc/init.d/vector <<EOF
#!/sbin/openrc-run

supervisor=supervise-daemon

name="vector"
description="A high-performance observability data pipeline.  https://vector.dev/"
command="/usr/local/bin/vector"
pidfile="/run/vector.pid"
required_dirs="/var/lib/vector"

extra_started_commands="reload"
description_reload="Reload configuration"

command_args="\$vector_opts"

depend() {
	need net
	after firewall
}

reload() {
        ebegin "Reloading vector configuration"
        \$supervisor \$RC_SVCNAME --signal HUP --pidfile \$pidfile
        eend \$?
}
EOF

    [ -d "$tmp"/etc/vector ] || mkdir --mode=0755 "$tmp"/etc/vector
    makefile root:root 0644 "$tmp"/etc/vector/vector.toml <<EOF
[sources.messages]
type = "file"
ignore_older_secs = 600
include = ["/var/log/messages*"]
read_from = "beginning"

# Parse Syslog logs
# See the Vector Remap Language reference for more info: https://vrl.dev
[transforms.parse_logs]
type = "remap"
inputs = ["messages"]
source = '''
. = parse_syslog!(string!(.message))
'''

# replace with an appropriate sink
[sinks.placeholder_replace_me]
type = "blackhole"
inputs = ["parse_logs"]
EOF

    [ -d "$tmp"/var ] || mkdir --mode=0755 "$tmp"/var
    [ -d "$tmp"/var/lib ] || mkdir --mode=0755 "$tmp"/var/lib
    [ -d "$tmp"/var/lib/vector ] || mkdir --mode=0755 "$tmp"/var/lib/vector
}

# Use $HL_NTP_SERVER, if set, as the NTP server or pool.ntp.org otherwise.
# Most targets lack real-time clocks, so force clock reset after boot when time is obviously wrong.
configure_chrony_as_client() {
        [ -d "$tmp"/etc/chrony ] || mkdir --mode=0755 "$tmp"/etc/chrony
        makefile root:root 0644 "$tmp"/etc/chrony/chrony.conf <<EOF
pool ${HL_NTP_SERVER:-pool.ntp.org} iburst
initstepslew 10 ${HL_NTP_SERVER:-pool.ntp.org}
driftfile /var/lib/chrony/chrony.drift
rtcsync
cmdport 0
EOF

	mkdir -p "$tmp"/etc/init.d
	makefile root:root 0755 "$tmp"/etc/init.d/fix_clock <<EOF
#!/sbin/openrc-run

description="Adjust clock with chronyc if current timestamp is before build date of rootfs"

attempt_clock_sync() {
        timeout \$1 sh -c 'while (touch /tmp/ts && test /etc/init.d/fix_clock -nt /tmp/ts); do echo "Attempting to adjust clock."; chronyc "burst 3/3" && sleep 10 && chronyc makestep; done'
	rm -f /tmp/ts
}

depend() {
	need net
	use dns
}

start() {
	ebegin "Check if chronyc is present"
	if ! command -v chronyc > /dev/null; then
		eend 1 "chronyc command is missing"
		return 1
	fi
	eend 0

	ebegin "Adjusting clock"
	attempt_clock_sync 40
	eend \$?
}
EOF

	# rc_add fix_clock boot
}


# use $HL_WIFI_SSID and $HL_WIFI_PSK to create /etc/wpa_supplicant/wpa_supplicant.conf
configure_wifi() {
    if [ -z "$HL_WIFI_SSID" ] || [ -z "$HL_WIFI_PSK" ]; then
        _err "Set environment variables HL_WIFI_SSID and HL_WIFI_PSK for WiFi configuration."
        return 1
    fi

    [ -d "$tmp"/etc ] || mkdir --mode=0755 "$tmp"/etc
    [ -d "$tmp"/etc/wpa_supplicant ] || mkdir --mode=0755 "$tmp"/etc/wpa_supplicant

    cat <<EOF > "$tmp"/etc/wpa_supplicant/wpa_supplicant.conf
network={
    ssid="$HL_WIFI_SSID"
    psk=$HL_WIFI_PSK
}
EOF
    chmod 0600 "$tmp"/etc/wpa_supplicant/wpa_supplicant.conf
    apk_add wpa_supplicant
    rc_add wpa_supplicant default
}


# DHCP assigned hostname should override hostname in image
set_hostname_with_udhcpc() {
    [ -d "$tmp"/etc ] || mkdir --mode=0755 "$tmp"/etc
    [ -d "$tmp"/etc/udhcpc ] || mkdir --mode=0755 "$tmp"/etc/udhcpc
    [ -d "$tmp"/etc/udhcpc/post-bound ] || mkdir --mode=0755 "$tmp"/etc/udhcpc/post-bound
    makefile root:root 0755 "$tmp"/etc/udhcpc/post-bound/hostname <<EOF
[ -n "\$hostname" ] && hostname "\$hostname"
EOF
}

install_overlays() {
    if [ -n "$HL_OVERLAY_DIR" ] && [ -d "$HL_OVERLAY_DIR" ]; then
        for T in "$HL_OVERLAY_DIR"/*.tgz; do
            if [ -e "$T" ]; then
                name="$(basename "$T")"
                echo "Extracting $name overlay..."
                tar -C "$tmp" -xzf "$T"
            fi
        done
    fi
}

tmp="$(mktemp -d)"
