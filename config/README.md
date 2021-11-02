Example boot-time configuration files for images.

The images in this repo are very opinionated and many choices are
baked into the images.  But there are a few configuration values that
can be set when the image boots for the first time.  This directory
holds examples of those config files.  Currently the config files are
only for raspberry pi images where the image tarball is written to a
FAT filesystem on SD card.

To use an example configuration, modify it as needed and then copy it
to the root of the first partition on the SD Card as `config.yaml`.
Early during the first boot, the values in `config.yaml` will be
[applied to the image] and [saved with `lbu commit`].

[applied to the image]: https://github.com/bfritz/homelab-bootstrap/blob/v0.0.1/scripts/genapkovl-rpi-firewall.sh#L243-L272
[saved with `lbu commit`]: https://github.com/bfritz/homelab-bootstrap/blob/v0.0.1/scripts/genapkovl-rpi-firewall.sh#L287-L306
