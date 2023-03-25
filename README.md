# bfritz homelab bootstrap scripts

<!-- badges -->
[![continuous integration status](https://github.com/bfritz/homelab-bootstrap/actions/workflows/ci.yaml/badge.svg)](https://github.com/bfritz/homelab-bootstrap/actions/workflows/ci.yaml)
[![Bors enabled](https://bors.tech/images/badge_small.svg)](https://app.bors.tech/repositories/38911)

Build scripts that use [qemu] and [alpine-chroot-install] to create custom
Alpine images that run from RAM.  Images include:

* k0s-worker - `x86_64` image to run as [k0s] worker node
* rpi-basic - `armhf` and `armv7` images for basic Raspberry Pi 0, 2, 3, or 4 host
* rpi-firewall - `armv7` image to run [awall], [dnsmasq], and [wireguard] on Raspberry Pi 4 as home router
* rpi-gem - `armhf` image to bridge [GreenEye Monitor] to time-series database using Raspberry Pi Zero W
* rpi-k0s-controller - `armv7` image to run as [k0s] controller node
* rpi-ruuvi - `armhf` image to listen for [Ruuvi Tag] data on a Raspberry Pi Zero W
* rpi-snapcast-client - `armhf` image to run [snapcast] on a Raspberry Pi Zero W

These [Alpine Linux] images run on my home network and are rather opinionated.
No image tarballs are published because it is unlikely they would be generally
useful.  However, the scripts that generate them might be interesting to others
and are the main reason for publishing.


## Image Details

### All Images

All images run [chrony] for NTP time sync, sshd, and the Prometheus [node-exporter]
to expose host metrics.

### k0s-worker

Image for x86_64 machines that will be provisioned to run the [k0s] distribution
of Kubernetes.  Intended as the foundation for kubernetes worker nodes that will
be provisioned with [k0sctl].

### rpi-basic

Image for Raspberry Pi Zero, 2, 3, or 4 to act as a basic host.
Mostly used for adhoc testing.

Pulls dhcp lease on wired interface and runs openssh server. `root`
user does not have password and the only way to login with ssh is
with key-based authenticateion.  Set `HL_SSH_KEY_URL` to the URL of
a [ssh authorized_keys file] to pre-authorize one or more keys.

Runs consoles on `tty1` and `ttyACM0`, the Pi's
[built-in serial port].  Boot messages are logged to serial console.

### rpi-firewall

Firewall image intended for Raspberry Pi 4.  The iptables firewall rules, stored
in a separate repo, are defined using [awall].   [VLANs] are used so the Pi, with
a single ethernet interface, can support multiple network zones.  Includes
[wireguard] to create VPN tunnels.  Also runs chrony in ntp server mode.

Runs consoles on `tty1` and `ttyACM0`, the Pi's [built-in serial port].  Boot
messages are logged to serial console.

Replaces a similar setup with [Seagate DockStar] running [ArchLinux ARM] and
[Shorewall] that served as my home router for many years.

### rpi-gem

Minimal image intended to bridge [GreenEye Monitor] from Brultech Research
to home network using Raspberry Pi Zero W.  Connection from Pi to GEM is
via USB-to-RS232 dongle.

### rpi-k0s-controller

[k0s] controller node for Raspberry Pi 4.  Intended as foundation for
controllers that will be provisioned with [k0sctl].

### rpi-snapcast-client

Minimal image with the [snapcast] client software installed.  Intended
to run on Raspberry Pi Zero W connected to amplifer for streaming audio.
Set `HL_SNAPCAST_SERVER` to the hostname of the snapcast server the
client should connect to at boot.


## Prior Art and Inspiration

* [alpine-composer](https://github.com/ggpwnkthx/alpine-composer) by [Isaac Jessup](https://github.com/ggpwnkthx)
* [knoopx/alpine-raspberry-pi](https://github.com/knoopx/alpine-raspberry-pi) by [Víctor Martínez](https://github.com/knoopx)


[alpine-chroot-install]: https://github.com/alpinelinux/alpine-chroot-install
[alpine linux]: https://alpinelinux.org/
[archlinux arm]: https://archlinuxarm.org/platforms/armv5/seagate-dockstar
[argocd]: https://argoproj.github.io/argo-cd/
[awall]: https://git.alpinelinux.org/awall/about/
[built-in serial port]: https://pinout.xyz/pinout/uart
[chrony]: https://chrony.tuxfamily.org/
[dnsmasq]: https://thekelleys.org.uk/dnsmasq/doc.html
[greeneye monitor]: https://www.brultech.com/greeneye/
[k0s]: https://k0sproject.io/
[k0sctl]: https://github.com/k0sproject/k0sctl
[node-exporter]: https://prometheus.io/docs/guides/node-exporter/
[ruuvi tag]: https://ruuvi.com/ruuvitag/
[seagate dockstar]: https://www.seagate.com/support/external-hard-drives/network-storage/dockstar/
[shorewall]: https://shorewall.org/
[snapcast]: https://github.com/badaix/snapcast#readme
[ssh authorized_keys file]: https://man.openbsd.org/sshd_config#AuthorizedKeysFile
[qemu]: https://qemu.org/
[vlans]: https://en.wikipedia.org/wiki/Virtual_LAN
[wireguard]: https://www.wireguard.com/
