#!/bin/sh -e

K0S_VER=1.26.0+k0s.0

hostname="$1"

basedir="$(dirname "$0")"
[ "$basedir" = "/bin" ] && basedir="./scripts" # shellspec workaround for $0 handling
. "$basedir"/shared.sh

is_controller() {
	test "$HL_HOSTNAME" = "k0s-controller"
}

k0s_arch() {
	case "$ARCH" in
		x86_64) echo "amd64" ;;
		aarch64) echo "arm64" ;;
		armv7) echo "arm" ;;
		?*)  _err "Unsupported k0s architecture: $ARCH" ;;
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
	fi
}

add_prepare_for_k8s_init_script() {
	if is_controller; then
		worker_only_calls=""
	else
		worker_only_calls="$(printf "share_sys\n\tsetup_for_cilium")"
	fi

	mkdir -p "$tmp"/etc/init.d
	makefile root:root 0755 "$tmp"/etc/init.d/prepare_for_k8s <<EOF
#!/sbin/openrc-run

description="Prepare host for running as kubernetes worker or controller node"

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

share_sys() {
	einfo "Sharing /sys with containers for node-exporter"
	mount --make-shared /
	mount --make-shared /sys
}

setup_for_cilium() {
	einfo "Mounting /sys/fs/bpf and sharing with containers for Cilium"
	mount bpffs -t bpf /sys/fs/bpf
	mount --make-shared /sys/fs/bpf

	einfo "Creating /run/cilium/cgroupv2 and sharing with containers for Cilium"
	mkdir -p /run/cilium/cgroupv2
	mount -t cgroup2 none /run/cilium/cgroupv2
	mount --make-shared /run/cilium/cgroupv2
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
