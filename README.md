# Alpine Homelab Bootstrap

Scripts to create custom Alpine images.  Images include:

* `x86_64` image with [k0s] and [ArgoCD] for home Kubernetes cluster
* `armhf` image to run [snapcast] on a Raspberry Pi Zero W
* `armv7` image to run [awall], [dnsmasq], and [wireguard] on Raspberry Pi 4 as home router

[argocd]: https://argoproj.github.io/argo-cd/
[awall]: https://git.alpinelinux.org/awall/about/
[dnsmasq]: https://thekelleys.org.uk/dnsmasq/doc.html
[k0s]: https://k0sproject.io/
[snapcast]: https://github.com/badaix/snapcast#readme
[wireguard]: https://www.wireguard.com/
