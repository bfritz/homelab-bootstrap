[mkimage] scripts to build our custom profiles.

These scripts [are combined] with those in [aports/scripts] to add our
custom Alpine profiles like `rpi-firewall` or `k0s-worker`.  The
`mkimg.*` files add the profiles and the `genapkovl-*` files are used
to customize the overlay tarball that is extracted over the root
filesystem during startup.

[aports/scripts]: https://gitlab.alpinelinux.org/alpine/aports/-/tree/master/scripts
[are combined]: https://github.com/bfritz/homelab-bootstrap/blob/v0.0.1/Makefile.images#L70-L71
[mkimage]: https://wiki.alpinelinux.org/wiki/How_to_make_a_custom_ISO_image_with_mkimage
