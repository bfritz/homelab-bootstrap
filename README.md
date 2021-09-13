# bfritz homelab bootstrap scripts

Build scripts that use [qemu] and [alpine-chroot-install] to create custom
Alpine images that run from RAM.  Images will include:

* [x] rpi-firewall - `armv7` image to run [awall], [dnsmasq], and [wireguard] on Raspberry Pi 4 as home router
* [ ] rpi-snapcast - `armhf` image to run [snapcast] on a Raspberry Pi Zero W
* [ ] k0s - `x86_64` image with [k0s] and [ArgoCD] for home Kubernetes cluster

These [Alpine Linux] images run on my home network and are rather opinionated.
No image tarballs are published because it is unlikely they would be generally
useful.  However, the scripts that generate them might be interesting to others
and are the main reason for publishing.


## Image Details

### All Images

All images run [chrony] for NTP time sync, sshd, and the Prometheus [node-exporter]
to expose host metrics.

### rpi-firewall

Firewall image intended for Raspberry Pi 4.  The firewall rules, stored in a
separate repo, are defined using [awall].   [VLANs] are used so the Pi, with a
single ethernet interface, can support multiple network zones.  Includes
[wireguard] to create VPN tunnels.

Runs consoles on `tty1` and `ttyACM0`, the Pi's [built-in serial port].  Boot
messages are logged to serial console.

Replaces a similar setup with [Seagate DockStar] running [ArchLinux ARM] and
[Shorewall] that served as my home router for many years.

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
[k0s]: https://k0sproject.io/
[node-exporter]: https://prometheus.io/docs/guides/node-exporter/
[seagate dockstar]: https://www.seagate.com/support/external-hard-drives/network-storage/dockstar/
[shorewall]: https://shorewall.org/
[snapcast]: https://github.com/badaix/snapcast#readme
[qemu]: https://qemu.org/
[vlans]: https://en.wikipedia.org/wiki/Virtual_LAN
[wireguard]: https://www.wireguard.com/
