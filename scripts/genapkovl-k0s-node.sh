#!/bin/sh -e

K0S_VER=1.34.3+k0s.0

hostname="$1"

basedir="$(dirname "$0")"
[ "$basedir" = "/bin" ] && basedir="./scripts" # shellspec workaround for $0 handling
. "$basedir"/shared.sh

is_controller() {
	test "$HL_HOSTNAME" = "k0s-controller"
}

k0s_arch() {
	case "$PLATFORM" in
		linux/amd64) echo "amd64" ;;
		linux/arm64) echo "arm64" ;;
		linux/arm/v6) echo "arm" ;;
		?*)  _err "Unsupported k0s platform: $PLATFORM" ;;
	esac
}

k0s_url() {
	k0s_arch="$(k0s_arch)"
	test -n "$k0s_arch" && echo "https://github.com/k0sproject/k0s/releases/download/v$K0S_VER/k0s-v$K0S_VER-$(k0s_arch)"
}

configure_installed_packages() {
	apk_add \
		chrony \
		openssh-server \
		findutils \
		coreutils \
		curl \
		iptables \
		nfs-utils \

	if is_controller; then
		apk_add prometheus-node-exporter
	else
		apk_add findmnt
	fi
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
	rc_add cgroups default
	rc_add machine-id default

	if is_controller; then
		rc_add node-exporter default
	else
		rc_add crond default
	fi
}

add_prepare_for_k8s_init_script() {
	if is_controller; then
		worker_only_calls=""
	else
		worker_only_calls="$(printf "share_mounts")"
	fi

	mkdir -p "$tmp"/etc/init.d
	makefile root:root 0755 "$tmp"/etc/init.d/prepare_for_k8s <<EOF
#!/sbin/openrc-run

description="Prepare host for running as kubernetes worker or controller node"

depend() {
	need dev localmount
}

mount_k8s_data_partitions() {
	ebegin "Mounting k8s data partitions"
	k8s_data_part="\$(blkid /dev/[hsv]d?? /dev/nvme?n?p? | sed -n '/LABEL=.k8s_data/p' | awk -F: '{print \$1}' | sort | head -n1)"

	if [ -z "\$k8s_data_part" ]; then
		eend 0 "no partitions labeled for k8s data"
		return 0
	fi

	einfo "Found k8s data partition at \$k8s_data_part .  Mounting at /data ."
	mkdir -p /data
	modprobe ext4 || true
	mount "\$k8s_data_part" /data

	for dir in /run/k0s/containerd /var/lib/k0s; do
		mkdir -p \$dir
		mkdir -p /data\$dir
		mount -o bind /data\$dir \$dir
		einfo "\$dir mounted as persistent volume."
	done
	eend 0
}

share_mounts() {
	einfo "Adding crontab to make sure mounts are shared correctly"

	cat <<EOS > /usr/local/bin/share_mounts.sh
#!/bin/sh

# Share / and /sys so node-exporter in k8s can access them.
# Share /sys/fs/bpf and /run/cilium/cgroupv2 so Cilium pods can access them.

for mnt in / /sys /sys/fs/bpf /run/cilium/cgroupv2; do
	if [ -e "\\\$mnt" ]; then
		prop="\\\$(findmnt --noheadings --output PROPAGATION \\\$mnt)"
		if [ "\\\$prop" != "shared"  ]; then
			mount --make-shared "\\\$mnt"
		fi
	fi
done
EOS

	chmod 0755 /usr/local/bin/share_mounts.sh

	if ! grep share_mounts /etc/crontabs/root; then
		echo "*/3	*	*	*	*	/usr/local/bin/share_mounts.sh" >> /etc/crontabs/root
	fi
}

start() {
	mount_k8s_data_partitions
	$worker_only_calls
}
EOF
	rc_add prepare_for_k8s boot
}

install_k0s() {
	# install k0s
	[ -d "$tmp"/usr ] || mkdir --mode=0755 "$tmp"/usr
	[ -d "$tmp"/usr/local ] || mkdir --mode=0755 "$tmp"/usr/local
	[ -d "$tmp"/usr/local/bin ] || mkdir --mode=0755 "$tmp"/usr/local/bin

	k0s_url="$(k0s_url)"
	if [ -n "$k0s_url" ]; then
		echo "Downloading k0s from URL: $k0s_url"
		curl -Lf# "$k0s_url" > "$tmp"/usr/local/bin/k0s
		chmod 755 "$tmp"/usr/local/bin/k0s
	else
		return 1
	fi
}

${__SOURCED__:+return} # stop here when sourced for shellspec

tmp="$(mktemp -d)"
trap cleanup EXIT

hostname="${HL_HOSTNAME:-k0s-worker}"
mkdir --mode=0755 "$tmp"/etc
makefile root:root 0644 "$tmp"/etc/hostname <<EOF
$hostname
EOF

configure_network
set_hostname_with_udhcpc
configure_installed_packages
configure_chrony_as_client
add_ssh_key
configure_init_scripts
add_prepare_for_k8s_init_script
install_k0s

tar -c -C "$tmp" etc root usr/local | gzip -9n > "$hostname".apkovl.tar.gz
